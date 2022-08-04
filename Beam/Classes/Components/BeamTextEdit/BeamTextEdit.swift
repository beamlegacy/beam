//
//  TextEdit.swift
//  Beam
//
//  Created by Sebastien Metrot on 27/09/2020.
//  Copyright © 2020 Beam. All rights reserved.
//
// swiftlint:disable file_length

import Foundation
import AppKit
import Combine
import BeamCore
import Swime

protocol BeamTextEditContainer {
    func invalidateLayout()
}

public struct SearchResult {
    public init(element: ElementNode, ranges: [NSRange]) {
        self.element = element
        self.ranges = ranges
    }

    public let element: ElementNode
    public let ranges: [NSRange]

    func getPositions() -> [Double] {
        let verticalPositions = ranges.map({ (range: NSRange) -> Double in
            let position = range.lowerBound
            let caretIndex = element.caretIndexForSourcePosition(position) ?? 0
            let rect = element.rectAt(caretIndex: caretIndex)
            let origin = rect.origin
            return Double(origin.y + element.offsetInDocument.y)
        })
        return verticalPositions
    }
}

public extension CALayer {
    var superlayers: [CALayer] {
        guard let superlayer = superlayer else { return [] }
        return superlayer.superlayers + [superlayer]
    }

    var deepContentsScale: CGFloat {
        get {
            contentsScale
        }
        set {
            contentsScale = newValue
            for l in sublayers ?? [] {
                l.deepContentsScale = newValue
            }
        }
    }
}

// swiftlint:disable:next type_body_length
@objc public class BeamTextEdit: NSView, NSTextInputClient, CALayerDelegate {
    var data: BeamData?
    public private(set) weak var state: BeamState?

    var cardTopSpace: CGFloat {
        journalMode ? PreferencesManager.editorJournalTopPadding : PreferencesManager.editorCardTopPadding
    }
    var centerText = false {
        didSet {
            guard centerText != oldValue else { return }
            setupCardHeader()
        }
    }

    private var _isTodaysNote: Bool = false
    var isTodaysNote: Bool {
        _isTodaysNote
    }
    var initialScrollOffset: CGFloat?
    var note: BeamElement {
        didSet {
            _isTodaysNote = note.note?.isTodaysNote ?? false
            note.updateNoteNamesInInternalLinks(recursive: true)
            updateRoot(with: note)
            searchViewModel?.search()
            updateCalendarLeadingGutter(for: note)
        }
    }

    public var enableDelayedInit: Bool
    public private(set) var delayedInit: Bool
    func updateRoot(with note: BeamElement) {
        sign.begin(Signs.updateRoot)

        guard note != rootNode?.element else { return }

        clearRoot()
        if rootNode != nil {
            scroll(.zero)
        }

        let initRootNode: () -> TextRoot = {
            self.sign.begin(Signs.updateLayout_initRootNode)
            defer { self.sign.end(Signs.updateLayout_initRootNode) }

            let root = TextRoot(editor: self, element: note, availableWidth: Self.textNodeWidth(for: self.frame.size))
            if let window = self.window {
                root.contentsScale = window.backingScaleFactor
            }

            return root
        }

        let initLayout: (TextRoot) -> Void = { root in
            self.sign.begin(Signs.updateLayout_initLayout)
            defer { self.sign.end(Signs.updateLayout_initLayout) }

            root.element
                .changed
                .debounce(for: .seconds(1), scheduler: RunLoop.main)
                .sink { [weak self] change in
                    guard change.1 == .text || change.1 == .tree else { return }
                    self?.searchViewModel?.search()
                }.store(in: &self.noteCancellables)
            self.delayedInit = false
            self.rootNode = root
            let newSize = self.computeIntrinsicContentSize()
            let newFrame = CGRect(origin: self.frame.origin, size: CGSize(width: max(self.frame.width, newSize.width), height: max(newSize.height, self.frame.height)))
            self.frame = newFrame
            DispatchQueue.main.async {
                self.invalidateLayout()
            }
            self.sign.end(Signs.updateRoot)
        }

        if enableDelayedInit, let note = note as? BeamNote {
            self.sign.begin(Signs.updateRoot_delayedInit)
            delayedInit = true
            let rect = nodesRect
            let refsAndLinks = note.fastLinksAndReferences.compactMap { $0.noteID }
            BeamNote.loadNotes(refsAndLinks) { notes in
                DispatchQueue.main.async {
                    self.preloadedLinksAndRefs = notes
                    let root = initRootNode()
                    DispatchQueue.userInteractive.async {
                        root.setLayout(rect)
                        DispatchQueue.main.async {
                            initLayout(root)
                            self.preloadedLinksAndRefs = []
                            self.sign.end(Signs.updateRoot_delayedInit)
                        }
                    }
                }
            }
        } else {
            initLayout(initRootNode())
        }
    }

    private var preloadedLinksAndRefs = [BeamNote]()

    private func clearRoot() {
        if let layers = layer?.sublayers {
            for l in layers where ![cardHeaderLayer, cardTimeLayer].contains(l) {
                l.removeFromSuperlayer()
            }
        }

        rootNode?.clearMapping() // Clear all previous references in the node tree
        rootNode?.editor = nil
        rootNode = nil
        // Remove all subsciptions:
        noteCancellables.removeAll()
        safeContentSize = .zero
        realContentSize = .zero
        invalidateLayout()
    }

    private var noteCancellables = [AnyCancellable]()

    // Formatter properties
    internal var displayedInlineFormatterKind: FormatterKind = .none
    internal var inlineFormatter: FormatterView?

    internal var formatterTargetRange: Range<Int>?
    internal var formatterTargetNode: TextNode?
    internal var isInlineFormatterHidden = true

    func addToMainLayer(_ layer: CALayer, at index: UInt32? = nil) {
        //Logger.shared.logDebug("addToMainLayer: \(layer.name)")
        DispatchQueue.mainSync {
            if let index = index {
                self.layer?.insertSublayer(layer, at: index)
            } else {
                self.layer?.addSublayer(layer)
            }
        }
    }

    let cardHeaderLayer = CALayer()
    let cardSeparatorLayer = CALayer()
    let cardTitleLayer = CATextLayer()
    let cardTimeLayer = CATextLayer()

    private (set) var isResizing = false
    public private (set) var journalMode: Bool

    public override var wantsUpdateLayer: Bool { true }
    internal var scope = Set<AnyCancellable>()

    public init(root: BeamElement, journalMode: Bool, enableDelayedInit: Bool, frame: CGRect? = nil, state: BeamState? = nil) {
        self.enableDelayedInit = enableDelayedInit
        self.delayedInit = enableDelayedInit
        self.journalMode = journalMode
        self.state = state
        self.data = state?.data

        note = root

        super.init(frame: NSRect())
        self.state?.currentEditor = self
        self.sign = Self.signPost.createId(object: self)

        setAccessibilityIdentifier("TextEdit")
        setAccessibilityLabel("Note Editor")
        setAccessibilityTitle((root as? BeamNote)?.title)

        let l = CALayer()
        self.layer = l
        l.backgroundColor = BeamColor.Generic.background.cgColor
        l.name = Self.mainLayerName
        l.delegate = self
        self.wantsLayer = true

        timer.setEventHandler { [unowned self] in
            if hasFocus {
                blinkPhase.toggle()
                if let focused = focusedWidget as? ElementNode {
                    focused.updateCursor()
                }
                if blinkPhase {
                    timer.schedule(deadline: .now()+onBlinkTime, leeway: .milliseconds(Int(onBlinkTime*100)))
                } else {
                    timer.schedule(deadline: .now()+offBlinkTime, leeway: .milliseconds(Int(offBlinkTime*100)))
                }
            }
        }
        timer.schedule(deadline: .now()+onBlinkTime, leeway: .milliseconds(Int(onBlinkTime*100)))
        timer.activate()

        initBlinking()
        unpreparedRoot = root

        setupCardHeader()
        registerForDraggedTypes([.fileURL])
        refreshAndHandleDeletionsAsync()

        if let frame = frame {
            self.frame = frame
            if !enableDelayedInit {
                prepareRoot()
            }
        }

    }

    var unpreparedRoot: BeamElement?

    var didJustMoveToWindow = false
    public override func viewDidMoveToWindow() {
        didJustMoveToWindow = true
        DispatchQueue.main.async { [weak self] in
            self?.didJustMoveToWindow = false
        }
        rootNode?.dispatchDidMoveToWindow(window)
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        setupInScrollView()
    }

    func setupInScrollView() {
        guard !journalMode, let scrollView = enclosingScrollView else { return }
        let documentView = scrollView.documentView
        documentView?.postsFrameChangedNotifications = true
        let contentView = scrollView.contentView
        contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contentOffsetDidChange(notification:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: contentView)
    }

    @objc private func contentOffsetDidChange(notification: Notification) {
        if enclosingScrollView != nil {
            if visibleRect.maxY >= realContentSize.height {
                invalidateLayout()
            }
        }
    }

    func refreshAndHandleDeletionsAsync() {
        // This was disabled because it produced a freeze when opening a note
        // see https://gitlab.com/beamgroup/beam/-/merge_requests/1026#note_641742413
//        let root = self.note
//        if let documentStruct = root?.note?.documentStruct {
//            // TODO: remove this when we add websocket sync
//            self.documentManager.refresh(documentStruct, false)
//        }
//        root?.updateNoteNamesInInternalLinks(recursive: true)
    }

    deinit {
        timer.cancel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isResizing = true
        hideInlineFormatter()
    }

    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isResizing = false
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()

        updateColors()
        rootNode?.updateColorsIfNeeded()
    }

    let timer = DispatchSource.makeTimerSource(queue: .main)

    var minimumWidth: CGFloat = 300 {
        didSet {
            if oldValue != minimumWidth {
                invalidateLayout()
            }
        }
    }
    var maximumWidth: CGFloat = 1024 {
        didSet {
            if oldValue != maximumWidth {
                invalidateLayout()
            }
        }
    }

    var leadingPercentage: CGFloat = 50 {
        didSet {
            if oldValue != leadingPercentage {
                invalidateLayout()
            }
        }
    }

    var showTitle = true {
        didSet {
            cardHeaderLayer.isHidden = !showTitle
        }
    }

    public var activated: () -> Void = { }
    public var activateOnLostFocus = true
    public var useFocusRing = false

    public var openURL: (URL, BeamElement, _ inBackground: Bool) -> Void = { _, _, _ in }
    public var openCard: (_ noteId: UUID, _ elementId: UUID?, _ unfold: Bool?) -> Void = { _, _, _ in }
    public var startQuery: (TextNode, Bool) -> Void = { _, _ in }

    public var onStartEditing: (() -> Void)?
    public var onEndEditing: (() -> Void)?
    public var onFocusChanged: ((UUID, Int) -> Void)?
    var onSearchToggle: (SearchViewModel?) -> Void = { _ in }
    var searchViewModel: SearchViewModel? {
        didSet {
            onSearchToggle(searchViewModel)
        }
    }

    var searchResults: [SearchResult]?

    let mouseCursorManager = MouseCursorManager()

    public var config = TextConfig()

    var selectedTextRange: Range<Int> {
        get {
            rootNode?.state.selectedTextRange ?? 0..<0
        }
        set {
            assert(newValue.lowerBound != NSNotFound)
            assert(newValue.upperBound != NSNotFound)
            rootNode?.state.selectedTextRange = newValue
            reBlink()
        }
    }

    var selectedText: String {
        return rootNode?.selectedText ?? ""
    }

    static let smallTreshold = CGFloat(500)
    static let bigThreshold = CGFloat(1024)
    var isBig: Bool {
        frame.width >= Self.bigThreshold
    }

    public override var frame: NSRect {
        didSet {
            let oldbig = oldValue.width >= Self.bigThreshold
            let newbig = isBig

            if oldbig != newbig {
                rootNode?.deepInvalidateText()
                invalidateLayout()
            }
        }
    }

    var currentIndicativeLayoutHeight: CGFloat = 0
    func appendToCurrentIndicativeLayoutHeight(_ height: CGFloat) {
        currentIndicativeLayoutHeight += height
    }
    var remainingIndicativeVisibleHeight: CGFloat? {
        guard let h = window?.frame.height ?? NSScreen.main?.visibleFrame.height
        else {
            return nil
        }
        // 30 pixel sounds reasonable so that we get at least one line of text layout
        return max(30, (h - (currentIndicativeLayoutHeight + topOffsetActual)))
    }

    var shouldDisableAnimationAtNextLayout = false
    func disableAnimationAtNextLayout() {
        shouldDisableAnimationAtNextLayout = true
    }

    func prepareRoot() {
        sign.begin(Signs.prepareRoot)
        defer {
            sign.end(Signs.prepareRoot)
        }

        guard let root = unpreparedRoot else { return }
        unpreparedRoot = nil
        let old = inRelayout
        inRelayout = true
        updateRoot(with: root)
        inRelayout = old
    }

    func relayoutRoot() {
        sign.begin(Signs.relayoutRoot)
        defer {
            sign.end(Signs.relayoutRoot)
        }

        currentIndicativeLayoutHeight = 0
        if !frame.isEmpty {
            prepareRoot()
        }

        currentIndicativeLayoutHeight = 0
        layoutInvalidated = false
        updateLayout(nodesRect)

        if !journalMode, let initialScrollOffset = initialScrollOffset, bounds.size.height >= intrinsicContentSize.height {
            scrollToVisible(NSRect(origin: NSPoint(x: 0, y: initialScrollOffset), size: visibleRect.size))
            self.initialScrollOffset = nil
        }
    }

    internal var nodesRect: NSRect {
        let r = frame
        let textNodeWidth = Self.textNodeWidth(for: frame.size)
        var rect = NSRect()

        if centerText {
            let x = (frame.width - textNodeWidth) / 2
            rect = NSRect(x: x, y: topOffsetActual + cardTopSpace, width: textNodeWidth, height: r.height)
        } else {
            let x = (frame.width - textNodeWidth) * (leadingPercentage / 100)
            rect = NSRect(x: x, y: topOffsetActual + cardTopSpace, width: textNodeWidth, height: r.height)
        }
        return rect
    }

    private func updateLayout(_ rect: NSRect) {
        sign.begin(Signs.updateLayout)
        defer {
            sign.end(Signs.updateLayout)
        }

        guard let rootNode = rootNode else { return }
        let textNodeWidth = Self.textNodeWidth(for: frame.size)
        let workBlock = { [weak self] in
            guard let self = self else { return }
            self.doRunBeforeNextLayout()

            rootNode.availableWidth = textNodeWidth
            self.updateCardHearderLayer(rect)
            self.rootNode?.setLayout(rect)
            self.updateTrailingGutterLayout(textRect: rect)
            if let cardNote = self.note as? BeamNote, cardNote.type.isJournal {
                self.setupLeadingGutter(textRect: rect)
                self.updateLeadingGutterLayout(textRect: rect)
            }

            self.doRunAfterNextLayout()
        }
        if isResizing || shouldDisableAnimationAtNextLayout || didJustMoveToWindow {
            shouldDisableAnimationAtNextLayout = false
            CATransaction.disableAnimations {
                workBlock()
            }
        } else {
            workBlock()
        }
    }

    static func textNodeWidth(for containerSize: CGSize) -> CGFloat {
        let clampedWidth = containerSize.width.clamp(Self.smallTreshold, Self.bigThreshold) - Self.smallTreshold
        let clampedRatio = clampedWidth / (Self.bigThreshold - Self.smallTreshold)
        let adjustmentAmplitude = maximumEmptyEditorWidth - minimumEmptyEditorWidth
        let computedWidth = Self.minimumEmptyEditorWidth + clampedRatio * adjustmentAmplitude
        let result = max(computedWidth, Self.minimumEmptyEditorWidth)
        return result
    }

    // This is the root node of what we are editing:
    var rootNode: TextRoot? {
        didSet {
            actualInvalidateLayout()
        }
    }

    // This is the node that the user is currently editing. It can be any node in the rootNode tree
    var focusedWidget: Widget? {
        get { rootNode?.focusedWidget }
        set {
            rootNode?.focusedWidget = newValue
        }
    }
    var mouseHandler: Widget? {
        get { rootNode?.mouseHandler }
        set { rootNode?.mouseHandler = newValue }
    }

    var topOffset: CGFloat = 28 { didSet { invalidateLayout() } }
    var footerHeight: CGFloat = 60 { didSet { invalidateLayout() } }
    var topOffsetActual: CGFloat {
        config.keepCursorMidScreen ? visibleRect.height / 2 : topOffset
    }

    func setupCardHeader() {
        cardHeaderLayer.name = "cardHeaderLayer"
        cardTitleLayer.name = "cardTitleLayer"
        cardTitleLayer.enableAnimations = false
        cardTimeLayer.enableAnimations = false
        cardHeaderLayer.enableAnimations = false
        cardHeaderLayer.isHidden = !showTitle

        updateCardTitleForHover(false)
        cardHeaderLayer.addSublayer(cardTitleLayer)
        addToMainLayer(cardHeaderLayer)
    }

    private func updateColors() {
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
        updateCardTitleForHover(false)
    }

    private func updateCardTitleForHover(_ hover: Bool) {
        guard let cardNote = note as? BeamNote, showTitle else { return }

        cardTitleLayer.string = NSAttributedString(string: cardNote.title, attributes: [
            .font: BeamFont.medium(size: PreferencesManager.journalCardTitleFontSize).nsFont,
            .foregroundColor: BeamColor.Generic.text.cgColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: hover ? BeamColor.Generic.text.cgColor : BeamColor.Generic.transparent.cgColor
        ])
    }

    private var cardHeaderPosY: CGFloat {
        return journalMode ? 0 : 127
    }

    private var cardTimePosY: CGFloat {
        return journalMode ? 44 : 104
    }

    func updateCardHearderLayer(_ rect: NSRect) {
        let cardHeaderPosX = rect.origin.x + 17
        cardHeaderLayer.frame = CGRect(origin: CGPoint(x: cardHeaderPosX, y: cardHeaderPosY), size: NSSize(width: rect.width, height: cardTitleLayer.preferredFrameSize().height))
        cardTitleLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: NSSize(width: cardTitleLayer.preferredFrameSize().width, height: cardTitleLayer.preferredFrameSize().height))
    }

    var sideLayerOffset: CGFloat = .zero {
        didSet {
            invalidateLayout()
        }
    }

    static let minimumEmptyEditorHeight = CGFloat(184)
    static let minimumEmptyEditorWidth = CGFloat(PreferencesManager.editorMinWidth)
    static let maximumEmptyEditorWidth = CGFloat(PreferencesManager.editorMaxWidth)
    var realContentSize: NSSize = .zero
    var safeContentSize: NSSize = .zero

    func computeIntrinsicContentSize() -> NSSize {
        guard !delayedInit, !frame.isEmpty, let rootNode = rootNode else {
            if let root = unpreparedRoot, journalMode {
                let fontSize = Int(TextNode.fontSizeFor(kind: .bullet)) * 3
                let size = root.allVisibleTexts.reduce(0) { partialResult, element in
                    partialResult + Int(1 + element.1.text.count / 80) * fontSize
                }
                let result = NSSize(width: AppDelegate.defaultWindowMinimumSize.width, height: max(Self.minimumEmptyEditorHeight, CGFloat(size)))
                return result
            }

            let result = NSSize(width: AppDelegate.defaultWindowMinimumSize.width, height: Self.minimumEmptyEditorHeight)
            return result
        }
        let textNodeWidth = Self.textNodeWidth(for: frame.size)
        rootNode.availableWidth = textNodeWidth
        let noteHeight = rootNode.idealSize.height + topOffsetActual + footerHeight + cardTopSpace
        let leadingGutterHeight = leadingGutterSize.height + topOffsetActual + footerHeight + cardTopSpace + cardHeaderPosY
        realContentSize = NSSize(width: max(AppDelegate.minimumSize(for: window).width, textNodeWidth), height: max(noteHeight, leadingGutterHeight))
        safeContentSize = realContentSize
        if !journalMode {
            safeContentSize.height = max(visibleRect.maxY, safeContentSize.height)
        }
        return safeContentSize
    }

    override public var intrinsicContentSize: NSSize {
        return computeIntrinsicContentSize()
    }

    private var dragging = false
    func startSelectionDrag() { dragging = true }
    func stopSelectionDrag() { dragging = false }

    public func setHotSpot(_ spot: NSRect) {
        guard !dragging else { return }
        guard !self.visibleRect.contains(spot) else { return }
        var centeredSpot = spot
        centeredSpot.size.height = max(centeredSpot.size.height, self.visibleRect.height / 2)
        _ = scrollToVisible(centeredSpot)
    }

    var layoutInvalidated = false
    public func invalidateLayout() {
        guard !inRelayout, !layoutInvalidated else { return }
        layoutInvalidated = true
        DispatchQueue.mainSync {
            self.invalidateIntrinsicContentSize()
        }

        if journalMode || realContentSize.height <= safeContentSize.height {
            // then we are identical, so the system will not call for a relayout
            actualInvalidateLayout()
        }
    }

    private func invalidateSuperViewIntrinsicContentSize() {
        guard let superStack = superview as? BeamTextEditContainer else {
            superview?.invalidateIntrinsicContentSize()
            return
        }
        superStack.invalidateLayout()
    }

    private func actualInvalidateLayout() {
        layoutInvalidated = true
        DispatchQueue.mainSync {
            self.invalidateSuperViewIntrinsicContentSize()
        }
        DispatchQueue.main.async { [weak self] in
            self?.relayoutRoot()
        }
    }

    var toRunBeforeNextLayout = [() -> Void]()
    var toRunAfterNextLayout = [() -> Void]()

    func runBeforeNextLayout(_ block: @escaping () -> Void) {
        toRunBeforeNextLayout.append(block)
    }

    func runAfterNextLayout(_ block: @escaping () -> Void) {
        toRunAfterNextLayout.append(block)
    }

    func doRunBeforeNextLayout() {
        for block in toRunBeforeNextLayout {
            block()
        }

        toRunBeforeNextLayout = []
    }

    func doRunAfterNextLayout() {
        for block in toRunAfterNextLayout {
            block()
        }

        toRunAfterNextLayout = []
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return rootNode?.hasMarkedText() ?? false
    }

    public func unmarkText() {
        rootNode?.unmarkText()
    }

    public func insertText(string: String, replacementRange: Range<Int>?) {
        guard let rootNode = rootNode,
              let node = focusedWidget as? ElementNode, !node.readOnly
        else { return }
        defer { inputDetectorLastInput = string }
        guard preDetectInput(string) else { return }
        rootNode.insertText(string: string, replacementRange: replacementRange)
        if let res = postDetectInput(string) {
            rootNode.state.attributes.append(res)
        }
        reBlink()
        updateInlineFormatterView(isKeyEvent: true)
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        return rootNode?.firstRect(forCharacterRange: range) ?? (.zero, 0..<1)
    }

    public var enabled = true

    var hasFocus = false

    public override func becomeFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = true
        if focusedWidget == nil {
            focusedWidget = rootNode?.children.first(where: { widget in
                widget as? ElementNode != nil
            })
            focusedWidget?.invalidate()
        }
        onStartEditing?()
        return true
    }

    public override func resignFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = false
        onEndEditing?()

        guard (inlineFormatter as? HyperlinkFormatterView) == nil else { return super.resignFirstResponder() }

        rootNode?.cancelSelection(.current)
        rootNode?.cancelNodeSelection()
        (focusedWidget as? TextNode)?.invalidateText() // force removing the syntax highlighting
        focusedWidget?.invalidate()
        focusedWidget?.onUnfocus()
        focusedWidget = nil
        if activateOnLostFocus { activated() }

        hideInlineFormatter()
        return true
    }

    func focusElement(withId elementId: UUID?, atCursorPosition: Int?, highlight: Bool = false, unfold: Bool = false) {
        guard let id = elementId,
              let element = note.findElement(id)
        else {
            self.scroll(.zero)
            return
        }

        guard let node = rootNode?.nodeFor(element) else {
            // the element exists but we don't yet have an UI for it, try again later:
            DispatchQueue.main.async { [weak self] in
                self?.focusElement(withId: elementId, atCursorPosition: atCursorPosition, highlight: highlight, unfold: unfold)
            }
            return
        }

        if unfold {
            node.allParents.forEach { ($0 as? ElementNode)?.unfold() }
            node.unfold()
        }
        self.setHotSpot(node.frameInDocument)
        self.focusedWidget = node
        node.focus(position: atCursorPosition)
        if highlight == true {
            node.highlight()
        }
    }

    func showElement(at height: Double, inElementWithId elementId: UUID?, unfold: Bool = false) {
        guard let id = elementId,
              let element = note.findElement(id),
              let node = rootNode?.nodeFor(element)
        else {
            self.scroll(.zero)
            return
        }

        if unfold {
            node.allParents.forEach { ($0 as? ElementNode)?.unfold() }
            node.unfold()
        }
        self.scroll(NSPoint(x: 0, y: CGFloat(height) - cardHeaderPosY))
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func pressEnter(_ option: Bool, _ command: Bool, _ shift: Bool, _ ctrl: Bool) {
        guard let rootNode = rootNode,
              let node = focusedWidget as? ElementNode
        else { return }

        if option || shift {
            rootNode.insertNewline()
            hideInlineFormatter()
        } else if ctrl, let textNode = node as? TextNode, case let .check(checked) = node.elementKind {
            node.cmdManager.formatText(in: textNode, for: .check(!checked), with: nil, for: nil, isActive: false)
        } else if inlineFormatter?.formatterHandlesEnter() != true {
            hideInlineFormatter()

            // swiftlint:disable:next empty_enum_arguments
            if case .check(_) = node.elementKind, node.elementText.isEmpty {
                guard let node = node as? TextNode else { return }
                node.cmdManager.formatText(in: node, for: .bullet, with: nil, for: nil, isActive: true)
                return
            }

            node.cmdManager.beginGroup(with: "Insert line")
            defer {
                node.cmdManager.endGroup()
            }

            guard let node = node as? TextNode, !node.readOnly else {
                rootNode.insertElementNearNonTextElement()
                return
            }
            if node.text.isEmpty && node.isEmpty && node.parent !== rootNode {
                rootNode.decreaseIndentation()
                return
            }

            let isOpenWithChildren = node.open && node.element.children.count > 0
            let insertAsChild = node.parent as? BreadCrumb != nil || node._displayedElement != nil || isOpenWithChildren && rootNode.cursorPosition == node.text.count

            if !rootNode.selectedTextRange.isEmpty {
                rootNode.cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
            }

            if let (linkString, linkRange) = linkStringForPrecedingCharacters(atIndex: rootNode.cursorPosition, in: node) {
                node.cmdManager.formatText(in: node, for: nil, with: .link(linkString), for: linkRange, isActive: false)
                addNoteSourceFrom(url: linkString)
            }

            guard let range = Range(safeBounds: (rootNode.cursorPosition, node.text.count)) else {
                Logger.shared.logError("""
                    Invalid range when pressing Enter, aborting... \
                    nodeText=\(node.text), cursorPosition=\(rootNode.cursorPosition), nodeTextCount=\(node.text.count)
                    """,
                    category: .noteEditor)
                return
            }
            let str = node.text.extract(range: range)
            if !range.isEmpty {
                node.cmdManager.deleteText(in: node, for: range)
            }

            let newElement = BeamElement(str)
            // swiftlint:disable:next empty_enum_arguments
            if case .check(_) = node.elementKind {
                newElement.kind = .check(false)
            }
            if insertAsChild {
                if let parent = node._displayedElement {
                    parent.open = true
                    node.cmdManager.insertElement(newElement, inElement: parent, afterElement: nil)
                } else {
                    node.open = true
                    node.cmdManager.insertElement(newElement, inNode: node, afterElement: nil)
                }
            } else {
                guard let parent = node.parent as? ElementNode else { return }
                let children = node.element.children

                parent.cmdManager.insertElement(newElement, inNode: parent, afterNode: node)
                guard let newElement = node.nodeFor(newElement)?.element else { return }
                newElement.open = node.open
                // reparent all children of node to newElement
                if isOpenWithChildren || !node.open && children.count > 0 && rootNode.cursorPosition == 0 {
                    for child in children {
                        node.cmdManager.reparentElement(child, to: newElement, atIndex: newElement.children.count)
                    }
                }
                if case .check = node.elementKind, node.elementText.isEmpty {
                    node.cmdManager.formatText(in: node, for: .bullet, with: nil, for: nil, isActive: true)
                }
            }

            if let toFocus = node.nodeFor(newElement) {
                toFocus.cmdManager.focusElement(toFocus, cursorPosition: 0)
            }
        }
    }

    var shift: Bool { NSEvent.modifierFlags.contains(.shift) }
    var option: Bool { NSEvent.modifierFlags.contains(.option) }
    var control: Bool { NSEvent.modifierFlags.contains(.control) }
    var command: Bool { NSEvent.modifierFlags.contains(.command) }

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    override open func keyDown(with event: NSEvent) {
        guard let rootNode = rootNode else { return }
        if self.hasFocus {
            hideMouseForEditing()

            switch event.keyCode {
            case KeyCode.escape.rawValue:
                rootNode.cancelSelection(.current)
                if inlineFormatter != nil {
                    hideInlineFormatter()
                } else if searchViewModel != nil {
                    cancelSearch()
                } else if let node = rootNode.focusedWidget as? ElementNode {
                    cancelBlockRefEditing(node)
                }
                return
            case KeyCode.enter.rawValue:
                if command && rootNode.state.nodeSelection == nil, inlineFormatter == nil,
                   let node = rootNode.focusedWidget as? TextNode, triggerCmdReturn(from: node) == true {
                    return
                }
            case KeyCode.up.rawValue:
                if rootNode.state.nodeSelection == nil, inlineFormatter == nil, let node = rootNode.focusedWidget as? ElementNode, node.children.count > 0, command, node.open {
                    toggleOpen(node)
                    return
                }
            case KeyCode.down.rawValue:
                if command, rootNode.state.nodeSelection == nil, inlineFormatter == nil,
                   let node = rootNode.focusedWidget as? ElementNode, node.children.count > 0, !node.open {
                    toggleOpen(node)
                    return
                }
            default:
                break
            }

            if let ch = event.charactersIgnoringModifiers {
                switch ch.lowercased() {
                case "[":
                    if command {
                        hideInlineFormatter()
                        rootNode.decreaseIndentation()
                        return
                    }
                case "]":
                    if command {
                        hideInlineFormatter()
                        rootNode.increaseIndentation()
                        return
                    }
                case "a":
                    if command && shift {
                        rootNode.selectAllNodes(force: true)
                        return
                    }
                #if DEBUG
                case "d":
                    if control, shift {
                        let str = [dumpWidgetTree(), dumpLayers()].flatMap { $0 }.joined(separator: "\n")
                        //swiftlint:disable:next print
                        print(str)
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(str, forType: .string)

                        return
                    }
                case "i":
                    if control, shift, command {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(self.note.id.uuidString, forType: .string)
                    }
                case "s":
                    if command, shift {
                        let encoder = JSONEncoder()
                        if let data = try? encoder.encode(note) {
                            if let str = String(data: data, encoding: .utf8) {
                                //swiftlint:disable:next print
                                print("JSON Dump of the current note:\n\n\(str)\n")
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(str, forType: .string)
                            }
                        }
                        return
                    }
                #endif
                default:
                    break
                }
            }
        }

        inputContext?.handleEvent(event)
    }

    func hideMouseForEditing() {
        guard let rootNode = rootNode else { return }
        mouseCursorManager.hideMouseCursorUntilNextMove(true)
        // dispatch hidden mouse events manually
        dispatchHover(Set<Widget>(), forceUpdate: true, last: nil)
        if let lastAppEvent = NSApp.currentEvent, lastAppEvent.type == .mouseMoved {
            let mouseInfo = MouseInfo(rootNode, CGPoint.zero, lastAppEvent)
            rootNode.dispatchMouseMoved(mouseInfo: mouseInfo)
        }
    }

    private func toggleOpen(_ node: ElementNode) {
        hideInlineFormatter()
        node.open.toggle()
    }

    private func cancelBlockRefEditing(_ node: ElementNode) {
        var blockRefNode = node as? BlockReferenceNode
        if node is ProxyNode {
            blockRefNode = node.allParents.first(where: { $0 is BlockReferenceNode }) as? BlockReferenceNode
        }
        blockRefNode?.readOnly = true
    }

    /// also known as instantSearch
    /// also known as searchFromNode
    /// - Returns: true if action is possible
    private func triggerCmdReturn(from node: TextNode) -> Bool {
        guard node.text.count > 0, !(node is BlockReferenceNode), !(node is ProxyNode)
        else { return false }

        let animator = TextEditCmdReturnAnimator(node: node, editorLayer: self.layer)
        let canAnimate = animator.startAnimation { [unowned self] in
            self.startQuery(node, true)
        }
        if canAnimate {
            blinkPhase = false
            hasFocus = false
            node.updateCursor()
            node.updateActionLayerVisibility(hidden: true)
        }
        return canAnimate
    }

    // NSTextInputHandler:
    // NSTextInputClient:
    public func insertText(_ string: Any, replacementRange: NSRange) {
        //        Logger.shared.logDebug("insertText \(string) at \(replacementRange)")
        let range = replacementRange.lowerBound == NSNotFound ? nil :  replacementRange.lowerBound..<replacementRange.upperBound
        // swiftlint:disable:next force_cast
        if let str = string as? String {
            insertText(string: str, replacementRange: range)
        } else if let str = string as? NSAttributedString {
            insertText(string: str.string, replacementRange: range)
        }
    }

    /* The receiver inserts string replacing the content specified by replacementRange. string can be either an NSString or NSAttributedString instance. selectedRange specifies the selection inside the string being inserted; hence, the location is relative to the beginning of string. When string is an NSString, the receiver is expected to render the marked text with distinguishing appearance (i.e. NSTextView renders with -markedTextAttributes).
     */
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        //        Logger.shared.logDebug("setMarkedText \(string) at \(replacementRange) with selection \(selectedRange)")
        // swiftlint:disable:next force_cast

        let selection = selectedRange.location == NSNotFound ? nil : selectedRange.lowerBound..<selectedRange.upperBound
        let replacement = replacementRange.location == NSNotFound ? nil : replacementRange.lowerBound..<replacementRange.upperBound
        if let str = string as? String {
            rootNode?.setMarkedText(string: str, selectedRange: selection, replacementRange: replacement)
        } else if let str = string as? NSAttributedString {
            rootNode?.setMarkedText(string: str.string, selectedRange: selection, replacementRange: replacement)
        }
        reBlink()
    }

    /* Returns the selection range. The valid location is from 0 to the document length.
     */
    public func selectedRange() -> NSRange {
        var r = NSRange()
            r = NSRange(location: selectedTextRange.lowerBound, length: selectedTextRange.upperBound - selectedTextRange.lowerBound)
//        Logger.shared.logDebug("selectedRange \(r)", category: .document)
        return r
    }

    /* Returns the marked range. Returns {NSNotFound, 0} if no marked range.
     */
    public func markedRange() -> NSRange {
        guard let range = rootNode?.markedTextRange else {
            return NSRange(location: NSNotFound, length: 0)
        }
        //        Logger.shared.logDebug("markedRange \(r)", category: .document)
        return NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound)
    }

    /* Returns attributed string specified by range. It may return nil. If non-nil return value and actualRange is non-NULL, it contains the actual range for the return value. The range can be adjusted from various reasons (i.e. adjust to grapheme cluster boundary, performance optimization, etc).
     */
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        //        Logger.shared.logDebug("attributedSubstring for \(range)")
        guard let node = focusedWidget as? TextNode else {
//            Logger.shared.logDebug("TextInput.attributedSubstring(range: \(range)) FAILED -> nil", category: .noteEditor)
            return nil
        }

        if let ptr = actualRange {
            ptr.pointee = range
        }
        let str = node.attributedString.attributedSubstring(from: range)
//        Logger.shared.logDebug("TextInput.attributedSubstring(range: \(range), actualRange: \(String(describing: actualRange))) -> \(str)", category: .noteEditor)
        return str
    }

    public func attributedString() -> NSAttributedString {
        guard let node = focusedWidget as? TextNode else {
//            Logger.shared.logDebug("TextInput.attributedString FAILED", category: .noteEditor)
            return "".attributed
        }
        let str = node.attributedString
//        Logger.shared.logDebug("TextInput.attributedString -> \"\(str)\"", category: .noteEditor)
        return str
    }

    /* Returns an array of attribute names recognized by the receiver.
     */
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        //        Logger.shared.logDebug("validAttributesForMarkedText")
        return []
    }

    /* Returns the first logical rectangular area for range. The return value is in the screen coordinate. The size value can be negative if the text flows to the left. If non-NULL, actuallRange contains the character range corresponding to the returned area.
     */
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        //        Logger.shared.logDebug("firstRect for \(range)")
        let (rect, _) = firstRect(forCharacterRange: range.lowerBound..<range.upperBound)
        let p = convert(rect, to: nil)
        let rc = window!.convertToScreen(p)
        return rc
    }

    /* Returns the index for character that is nearest to point. point is in the screen coordinate system.
     */
    public func characterIndex(for point: NSPoint) -> Int {
        //        Logger.shared.logDebug("characterIndex for \(point)")
        return positionAt(point: point)
    }

    // these undo/redo methods override the subviews undoManagers behavior
    // if we're not actually the first responder, let's just forward it.
    @IBAction func undo(_ sender: Any) {
        guard let rootNode = rootNode, rootNode.note != nil else { return }
        if let firstResponder = window?.firstResponder, let undoManager = firstResponder.undoManager, firstResponder != self {
            undoManager.undo()
            return
        }
        hideInlineFormatter()
        _ = rootNode.focusedCmdManager.undo(context: rootNode.cmdContext)
    }

    @IBAction func redo(_ sender: Any) {
        guard let rootNode = rootNode else { return }
        if let firstResponder = window?.firstResponder, let undoManager = firstResponder.undoManager, firstResponder != self {
            undoManager.redo()
            return
        }
        hideInlineFormatter()
        _ = rootNode.focusedCmdManager.redo(context: rootNode.cmdContext)
    }

    // MARK: Input detector properties
    // State to detect shortcuts: @ / [[ ]]
    internal var inputDetectorState: Int = 0
    internal var inputDetectorEnabled: Bool { inputDetectorState >= 0 }
    internal var inputDetectorLastInput: String = ""

    // MARK: Paste properties
    internal let supportedPasteObjects = [BeamNoteDataHolder.self, BeamTextHolder.self, NSURL.self, NSImage.self, NSAttributedString.self, NSString.self]
    internal let supportedPasteAsPlainTextObjects = [BeamTextHolder.self, NSAttributedString.self, NSString.self]

    func initBlinking() {
        let defaults = UserDefaults.standard
        let von = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOn")
        onBlinkTime = von == 0 ? onBlinkTime : von * 1000
        let voff = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOff")
        offBlinkTime = voff == 0 ? offBlinkTime : voff * 1000
    }

    func reBlink() {
        blinkPhase = true
        timer.schedule(deadline: .now()+onBlinkTime, leeway: .milliseconds(Int(onBlinkTime*100)))
        focusedWidget?.invalidate()
    }

    public func positionAt(point: NSPoint) -> Int {
        guard let node = focusedWidget as? TextNode else { return 0 }
        let fid = node.frameInDocument
        return node.positionAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    // MARK: - Mouse Event
    private func shouldAllowMouseEvents() -> Bool {
        state?.editorShouldAllowMouseEvents != false && inlineFormatter?.isMouseInsideView != true && enabled
    }
    private func shouldAllowHoverEvents() -> Bool {
        shouldAllowMouseEvents() && state?.editorShouldAllowMouseHoverEvents != false && !mouseCursorManager.isMouseCursorHidden && enabled
    }

    override public func updateTrackingAreas() {
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInActiveApp, .mouseEnteredAndExited, .cursorUpdate, .enabledDuringMouseDrag, .inVisibleRect], owner: self, userInfo: nil))
    }

    var mouseDownPos: NSPoint?
    private func handleMouseDown(event: NSEvent) {
        guard let rootNode = rootNode, shouldAllowMouseEvents() else { return }
        guard !(inputContext?.handleEvent(event) ?? false) else { return }
        reBlink()
        mouseDownPos = nil
        if event.clickCount == 1 { hideInlineFormatter() }
        self.mouseDownPos = convert(event.locationInWindow)
        let info = MouseInfo(rootNode, mouseDownPos ?? .zero, event)
        mouseHandler = rootNode.dispatchMouseDown(mouseInfo: info)
        if let mouseHandler = mouseHandler {
            cursorUpdate(with: event)
            mouseHandler.isDraggedForMove ? () : rootNode.cancelNodeSelection()
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        handleMouseDown(event: event)
    }

    public override func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        handleMouseDown(event: event)
        if window?.firstResponder != self {
            window?.makeFirstResponder(self)
        }
        mouseCursorManager.lockCursor = true
    }

    let scrollXBorder = CGFloat(20)
    let scrollYBorderUp = CGFloat(10)
    let scrollYBorderDown = CGFloat(90)

    public func setHotSpotToCursorPosition() {
        guard let rootNode = rootNode else { return }
        guard focusedWidget as? ElementNode != nil else { return }
        var rect = rectAt(caretIndex: rootNode.caretIndex).insetBy(dx: -scrollXBorder, dy: 0)
        rect.origin.y -= scrollYBorderUp
        rect.size.height += scrollYBorderUp + scrollYBorderDown
        setHotSpot(rect)
    }

    public func setHotSpotToNode(_ node: Widget) {
        setHotSpot(node.frameInDocument.insetBy(dx: -30, dy: -30))
    }

    public func rectAt(caretIndex position: Int) -> NSRect {
        guard let node = focusedWidget as? ElementNode else { return NSRect() }
        let origin = node.offsetInDocument
        return node.rectAt(caretIndex: position).offsetBy(dx: origin.x, dy: origin.y)
    }

    override public func mouseDragged(with event: NSEvent) {
        guard let rootNode = rootNode, shouldAllowMouseEvents() else { return }
        guard !(inputContext?.handleEvent(event) ?? false) else { return }

        //        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow)

        let widget = rootNode.dispatchMouseDragged(mouseInfo: MouseInfo(rootNode, point, event))

        defer {
            cursorUpdate(with: event)
            autoscroll(with: event)
        }

        //Prevent selection drag when resizing or moving a node
        if let resizable = widget as? ResizableNode, resizable.isResizing {
            return
        }

        if let elementNode = widget as? ElementNode, elementNode.isDraggedForMove {
            return
        }
        startSelectionDrag()
        mouseDraggedUpdate(with: event)
    }

    func convert(_ point: NSPoint) -> NSPoint {
        return self.convert(point, from: nil)
    }

    override public func mouseMoved(with event: NSEvent) {
        mouseCursorManager.mouseMoved()
        guard let rootNode = rootNode, shouldAllowMouseEvents() && shouldAllowHoverEvents() else { return }
        if showTitle {
            let titleCoord = cardTitleLayer.convert(event.locationInWindow, from: nil)
            let hoversCardTitle = cardTitleLayer.contains(titleCoord)
            updateCardTitleForHover(hoversCardTitle)
            if hoversCardTitle {
                mouseCursorManager.setMouseCursor(cursor: .pointingHand)
                return
            }
        }

        if !(window?.contentView?.frame.contains(event.locationInWindow) ?? false) {
            super.mouseMoved(with: event)
            return
        }

        let point = convert(event.locationInWindow)
        let mouseInfo = MouseInfo(rootNode, point, event)
        rootNode.dispatchMouseMoved(mouseInfo: mouseInfo)
        cursorUpdate(with: event)
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func mouseDraggedUpdate(with event: NSEvent) {
        guard let rootNode = rootNode, shouldAllowMouseEvents() else { return }
        guard let startPos = mouseDownPos else { return }
        let eventPoint = convert(event.locationInWindow)
        let widgets = rootNode.getWidgetsBetween(startPos, eventPoint)

        if let selection = rootNode.state.nodeSelection, let focusedNode = focusedWidget as? ElementNode {
            var textNodes = widgets.compactMap { $0 as? ElementNode }
            if eventPoint.y < startPos.y {
                textNodes = textNodes.reversed()
            }
            selection.start = focusedNode
            selection.append(focusedNode)
            for textNode in textNodes {
                if !selection.nodes.contains(textNode) {
                    selection.append(textNode)
                }
            }
            for selectedNode in selection.nodes {
                if !textNodes.contains(selectedNode) && selectedNode != focusedNode && !selectedNode.parentIsSelectedAndClosed {
                    selection.remove(selectedNode)
                }
            }
            if textNodes.isEmpty {
                selection.end = focusedNode
            } else {
                guard let lastNode = textNodes.last else { return }
                selection.end = lastNode
            }
        } else {
            if widgets.count > 0 {
                _ = rootNode.startNodeSelection()
            }
            return
        }
    }

    public override func cursorUpdate(with event: NSEvent) {
        guard let rootNode = rootNode, shouldAllowMouseEvents() else { return }

        let point = convert(event.locationInWindow)
        let views = rootNode.getWidgetsAt(point, point, ignoreX: true)
        let preciseViews = rootNode.getWidgetsAt(point, point, ignoreX: false)

#if DEBUG
        //swiftlint:disable print
        if event.modifierFlags.contains(.control) {
            print("Widgets:")
            for handler in preciseViews {
                print("\t\(handler) - \(handler.description)")
            }
        }
        //swiftlint:enable print
#endif

        let cursors = preciseViews.compactMap { $0.cursor }
        let cursor = cursors.last ?? .arrow
        mouseCursorManager.setMouseCursor(cursor: cursor)
        let widgets = views.compactMap { $0 as? Widget }
        dispatchHover(Set<Widget>(widgets), last: widgets.last)
    }

    func dispatchHover(_ widgets: Set<Widget>, forceUpdate: Bool = false, last: Widget?) {
        guard shouldAllowHoverEvents() || forceUpdate else { return }
        rootNode?.dispatchHover(widgets, last: last)
    }

    override public func mouseUp(with event: NSEvent) {
        mouseCursorManager.lockCursor = false
        guard let rootNode = rootNode, shouldAllowMouseEvents() else { return }
        guard !(inputContext?.handleEvent(event) ?? false) else { return }
        stopSelectionDrag()

        if showTitle {
            let titleCoord = cardTitleLayer.convert(event.locationInWindow, from: nil)
            if cardTitleLayer.contains(titleCoord) {
                guard let cardNote = note as? BeamNote else { return }
                self.openCard(cardNote.id, nil, nil)
                return
            }
        }

        let point = convert(event.locationInWindow)
        let info = MouseInfo(rootNode, point, event)
        if nil != rootNode.dispatchMouseUp(mouseInfo: info) {
            return
        }

        cursorUpdate(with: event)
        super.mouseUp(with: event)
        mouseHandler = nil
    }

    public override var acceptsFirstResponder: Bool { enabled }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return enabled
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        guard let window = newWindow else {
            _ = self.resignFirstResponder()
            if !journalMode {
                self.clearRoot()
            }
            return
        }
        window.acceptsMouseMovedEvents = true
        rootNode?.contentsScale = window.backingScaleFactor

        cardTitleLayer.contentsScale = window.backingScaleFactor
        cardTimeLayer.contentsScale = window.backingScaleFactor
    }

    var onBlinkTime: Double = 0.7
    var offBlinkTime: Double = 0.5
    var blinkPhase = true

    public override var isFlipped: Bool { true }

    // CALayerDelegate
    let titlePadding = CGFloat(20)

    var inRelayout = false
    public func layoutSublayers(of layer: CALayer) {
        inRelayout = true; defer { inRelayout = false }
        guard layer === self.layer else { return }
        relayoutRoot()
    }

    @IBAction func save(_ sender: Any?) {
        Logger.shared.logInfo("Save document!", category: .noteEditor)
        _ = rootNode?.note?.save(self)
    }

    @IBAction func selectAllHierarchically(_ sender: Any?) {
        rootNode?.selectAllNodesHierarchically()
    }

    func dumpWidgetTree() -> [String] {
        rootNode?.dumpWidgetTree() ?? []
    }

    func dumpSubLayers(_ layer: CALayer, _ level: Int) -> [String] {
        let tabs = String.tabs(level)
        var strs = [String]()
        for (i, l) in (layer.sublayers ?? []).enumerated() {
            strs.append("\(tabs)\(i) - '\(l.name ?? "unnamed")' - \(String(describing: l)) - pos \(l.position) - bounds \(l.bounds) \(l.isHidden ? "[HIDDEN]" : "")")
            strs.append(contentsOf: dumpSubLayers(l, level + 1))
        }
        return strs
    }

    func dumpLayers() -> [String] {
        // swiftlint:disable print
        var strs = ["================", "Dumping editor \(layer?.sublayers?.count ?? 0) layers:"]

        if let layer = layer {
            strs.append(contentsOf: dumpSubLayers(layer, 0))
        }
        strs.append("================")
        return strs
    }

    public override func accessibilityChildren() -> [Any]? {
        var children: [Any]?
        if let visibleChildren = rootNode?.allVisibleChildren {
            children = visibleChildren
        }
        if let superChildren = super.accessibilityChildren() {
            var copy = children ?? [Any]()
            copy.append(contentsOf: superChildren)
            children = copy
        }
        return children
    }

    public override var accessibilityFocusedUIElement: Any {
        return focusedWidget ?? self
    }

    /////////////////////////////////////
    /// NSResponder:
    override public func moveLeft(_ sender: Any?) {
        if control && option && command {
            guard let node = focusedWidget as? ElementNode else { return }
            node.fold()
            return
        }

        guard inlineFormatter?.formatterHandlesCursorMovement(direction: .left) != true else { return }

        rootNode?.moveLeft()
        hideInlineFormatter()
    }

    override public func moveRight(_ sender: Any?) {
        if control && option && command {
            guard let node = focusedWidget as? ElementNode else { return }
            node.unfold()
            return
        }

        guard inlineFormatter?.formatterHandlesCursorMovement(direction: .right) != true else { return }

        rootNode?.moveRight()
        hideInlineFormatter()
    }

    override public func moveLeftAndModifySelection(_ sender: Any?) {
        guard let rootNode = rootNode,
                let node = focusedWidget as? ElementNode, node.allowSelection else { return }
        let showFormatter = rootNode.cursorPosition != 0
        rootNode.moveLeftAndModifySelection()
        if showFormatter {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

    override public func moveWordRight(_ sender: Any?) {
        rootNode?.moveWordRight()
    }

    override public func moveWordLeft(_ sender: Any?) {
        rootNode?.moveWordLeft()
    }

    override public func moveWordRightAndModifySelection(_ sender: Any?) {
        rootNode?.moveWordRightAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveWordLeftAndModifySelection(_ sender: Any?) {
        rootNode?.moveWordLeftAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveRightAndModifySelection(_ sender: Any?) {
        guard let rootNode = rootNode,
                let node = focusedWidget as? ElementNode, node.allowSelection else { return }
        let showFormatter = rootNode.cursorPosition != node.textCount
        rootNode.moveRightAndModifySelection()
        if showFormatter {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

    override public func moveToBeginningOfLine(_ sender: Any?) {
        rootNode?.moveToBeginningOfLine()
        hideInlineFormatter()
    }

    override public func moveToEndOfLine(_ sender: Any?) {
        rootNode?.moveToEndOfLine()
        hideInlineFormatter()
        detectTextFormatterType()
    }

    override public func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        rootNode?.moveToBeginningOfLineAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        rootNode?.moveToEndOfLineAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    public override func moveToBeginningOfDocument(_ sender: Any?) {
        guard inlineFormatter?.formatterHandlesCursorMovement(direction: .up,
                                                              modifierFlags: .command) != true else { return }
        rootNode?.moveToBeginningOfDocument()
    }

    public override func moveToEndOfDocument(_ sender: Any?) {
        guard inlineFormatter?.formatterHandlesCursorMovement(direction: .down,
                                                              modifierFlags: .command) != true else { return }
        rootNode?.moveToEndOfDocument()
    }

    override public func moveUp(_ sender: Any?) {
        if control, option, command {
            guard let rootNode = rootNode else { return }
            if rootNode.state.nodeSelection == nil,
               inlineFormatter == nil,
               let node = rootNode.focusedWidget as? ElementNode,
               let previous = node.previousVisibleNode(ElementNode.self),
               let newParent = previous.parent as? ElementNode,
               let newIndex = previous.indexInParent {
                // move node up
                node.cmdManager.reparentElement(node, to: newParent, atIndex: newIndex)
                return
            }
        } else {
            if inlineFormatter?.formatterHandlesCursorMovement(direction: .up) != true {
                rootNode?.moveUp()
                hideInlineFormatter()
            }
        }
    }

    override public func moveDown(_ sender: Any?) {
        if control, option, command {
            guard let rootNode = rootNode else { return }
            if rootNode.state.nodeSelection == nil,
               inlineFormatter == nil,
               let node = rootNode.focusedWidget as? ElementNode,
               let next = node.nextVisibleNode(ElementNode.self, includingChildren: false),
               let newParent = next.parent as? ElementNode,
               let newIndex = next.indexInParent {
                // move node up
                node.cmdManager.reparentElement(node, to: newParent, atIndex: newIndex)
                return
            }
        } else {
            if inlineFormatter?.formatterHandlesCursorMovement(direction: .down) != true {
                rootNode?.moveDown()
                hideInlineFormatter()
            }
        }
    }

    var isOnlyOneThingSelected: Bool {
        return (rootNode?.state.nodeSelection?.nodes.count ?? 0) <= 1 && !selectedTextRange.isEmpty
    }

    override public func selectAll(_ sender: Any?) {
        guard let rootNode = rootNode,
              let node = focusedWidget as? ElementNode, node.allowSelection else { return }
        rootNode.selectAll()
        if isOnlyOneThingSelected {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        } else {
            hideInlineFormatter()
        }
    }

    override public func moveUpAndModifySelection(_ sender: Any?) {
        guard let rootNode = rootNode,
        let node = focusedWidget as? ElementNode, node.allowSelection else { return }
        rootNode.moveUpAndModifySelection()
        if isOnlyOneThingSelected {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

    override public func moveDownAndModifySelection(_ sender: Any?) {
        guard let rootNode = rootNode,
        let node = focusedWidget as? ElementNode, node.allowSelection else { return }
        rootNode.moveDownAndModifySelection()
        if isOnlyOneThingSelected {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

    override public func scrollPageUp(_ sender: Any?) {
        enclosingScrollView?.pageUp(sender)
    }

    override public func scrollPageDown(_ sender: Any?) {
        enclosingScrollView?.pageDown(sender)
    }

    override public func scrollLineUp(_ sender: Any?) {
        enclosingScrollView?.scrollLineUp(sender)
    }

    override public func scrollLineDown(_ sender: Any?) {
        enclosingScrollView?.scrollLineDown(sender)
    }

    override public func scrollToBeginningOfDocument(_ sender: Any?) {
        scroll(.zero)
    }

    override public func scrollToEndOfDocument(_ sender: Any?) {
        scroll(NSPoint(x: 0, y: frame.height))
    }

        /* Graphical Element transposition */

//    override public func transpose(_ sender: Any?) {
//    }
//
//    override public func transposeWords(_ sender: Any?) {
//    }

        /* Selections */

    override public func selectParagraph(_ sender: Any?) {
        rootNode?.selectAllNodesHierarchically()
    }

    override public func selectLine(_ sender: Any?) {
    }

    override public func selectWord(_ sender: Any?) {
    }

        /* Insertions and Indentations */

    override public func indent(_ sender: Any?) {
        rootNode?.increaseIndentation()
    }

    override public func insertTab(_ sender: Any?) {
        rootNode?.increaseIndentation()
    }

    override public func insertBacktab(_ sender: Any?) {
        rootNode?.decreaseIndentation()
    }

    override public func insertNewline(_ sender: Any?) {
        let shift = NSEvent.modifierFlags.contains(.shift)
        let option = NSEvent.modifierFlags.contains(.option)
        let command = NSEvent.modifierFlags.contains(.command)
        let control = NSEvent.modifierFlags.contains(.control)
        pressEnter(option, command, shift, control)
    }

    override public func insertLineBreak(_ sender: Any?) {
        let control = true
        pressEnter(false, false, false, control)
    }

//    override public func insertParagraphSeparator(_ sender: Any?) {
//    }
//
//    override public func insertNewlineIgnoringFieldEditor(_ sender: Any?) {
//    }
//
//    override public func insertTabIgnoringFieldEditor(_ sender: Any?) {
//    }
//
//    override public func insertLineBreak(_ sender: Any?) {
//    }
//
//    override public func insertContainerBreak(_ sender: Any?) {
//    }
//
//    override public func insertSingleQuoteIgnoringSubstitution(_ sender: Any?) {
//    }
//
//    override public func insertDoubleQuoteIgnoringSubstitution(_ sender: Any?) {
//    }

        /* Case changes */

//    override public func changeCaseOfLetter(_ sender: Any?) {
//    }
//
//    override public func uppercaseWord(_ sender: Any?) {
//    }
//
//    override public func lowercaseWord(_ sender: Any?) {
//    }
//
//    override public func capitalizeWord(_ sender: Any?) {
//    }

        /* Deletions */

    override public func deleteForward(_ sender: Any?) {
        guard let rootNode = rootNode else { return }
        rootNode.deleteForward()

        guard let node = focusedWidget as? TextNode else { return }
        if node.text.isEmpty || !rootNode.textIsSelected { hideInlineFormatter() }
        detectTextFormatterType()
    }

    override public func deleteBackward(_ sender: Any?) {
        guard let rootNode = rootNode else { return }
        rootNode.deleteBackward()

        updateInlineFormatterView(isKeyEvent: true)
//        guard let node = focusedWidget as? TextNode else { return }
//        if node.text.isEmpty || !rootNode.textIsSelected { hideInlineFormatter() }
        detectTextFormatterType()
    }

//    override public func deleteBackwardByDecomposingPreviousCharacter(_ sender: Any?) {
//    }

    override public func deleteWordForward(_ sender: Any?) {
        rootNode?.deleteWordForward()
        hideInlineFormatter()
    }

    override public func deleteWordBackward(_ sender: Any?) {
        rootNode?.deleteWordBackward()
        hideInlineFormatter()
    }

    override public func deleteToBeginningOfLine(_ sender: Any?) {
        rootNode?.deleteToBeginningOfLine()
        hideInlineFormatter()
    }

    override public func deleteToEndOfLine(_ sender: Any?) {
        rootNode?.deleteToEndOfLine()
        hideInlineFormatter()
    }

//    override public func deleteToBeginningOfParagraph(_ sender: Any?) {
//    }
//
//    override public func deleteToEndOfParagraph(_ sender: Any?) {
//    }
//
//    override public func yank(_ sender: Any?) {
//    }

        /* Completion */

    override public func complete(_ sender: Any?) {
    }

        /* Mark/Point manipulation */

//    override public func setMark(_ sender: Any?) {
//    }
//
//    override public func deleteToMark(_ sender: Any?) {
//    }
//
//    override public func selectToMark(_ sender: Any?) {
//    }
//
//    override public func swapWithMark(_ sender: Any?) {
//    }

        /* Cancellation */

    override public func cancelOperation(_ sender: Any?) {
        hideInlineFormatter()
    }

        /* Writing Direction */

//    override public func makeBaseWritingDirectionNatural(_ sender: Any?) {
//    }
//
//    override public func makeBaseWritingDirectionLeftToRight(_ sender: Any?) {
//    }
//
//    override public func makeBaseWritingDirectionRightToLeft(_ sender: Any?) {
//    }
//
//    override public func makeTextWritingDirectionNatural(_ sender: Any?) {
//    }
//
//    override public func makeTextWritingDirectionLeftToRight(_ sender: Any?) {
//    }
//
//    override public func makeTextWritingDirectionRightToLeft(_ sender: Any?) {
//    }

       /* Quick Look */
    /* Perform a Quick Look on the text cursor position, selection, or whatever is appropriate for your view. If there are no Quick Look items, then call [[self nextResponder] tryToPerform:_cmd with:sender]; to pass the request up the responder chain. Eventually AppKit will attempt to perform a dictionary look up. Also see quickLookWithEvent: above.
    */
//    override public func quickLookPreviewItems(_ sender: Any?) {
//    }

    // MARK: - Drag and drop:

    private struct DragResult: Equatable {
        let element: ElementNode
        let shouldBeAfter: Bool
        let shouldBeChild: Bool

        func onlyDiffersByIndentation(from otherResult: DragResult) -> Bool {
            return self.element == otherResult.element && self.shouldBeAfter == otherResult.shouldBeAfter && self.shouldBeChild != otherResult.shouldBeChild
        }
    }

    var dragIndicator = CALayer()
    private var previousDragResult: DragResult?

    /// Updates the drag indicator for the desired cursor position
    /// - Parameter point: The position of the cursor
    /// - Returns: A DragResult with the hovered ElementNode, a bool if we should add the dragged element after this node and
    /// another bool if we should make the element a child or a sibbling
    @discardableResult private func updateDragIndicator(at point: CGPoint?) -> DragResult? {
        guard let rootNode = rootNode else { return nil }
        guard let point = point,
              let node = rootNode.widgetAt(point: CGPoint(x: point.x, y: point.y - rootNode.frame.minY)) as? ElementNode else {
            dragIndicator.isHidden = true
            previousDragResult = nil
            return nil
        }

        if dragIndicator.superlayer == nil {
            layer?.addSublayer(dragIndicator)
        }

        dragIndicator.backgroundColor = BeamColor.Bluetiful.cgColor
        dragIndicator.borderWidth = 0
        dragIndicator.isHidden = false
        dragIndicator.zPosition = 10
        dragIndicator.cornerRadius = 1
        dragIndicator.opacity = 0.5

        // Should the dragged element be after or before the hovered widget?
        let shouldBeAfter: Bool
        if point.y < (node.offsetInDocument.y + node.contentsFrame.height / 2) {
            shouldBeAfter = false
        } else {
            shouldBeAfter = true
        }

        let yPos = shouldBeAfter ? node.offsetInDocument.y + node.contentsFrame.maxY : node.offsetInDocument.y + node.contentsFrame.minY
        var initialFrame = CGRect(x: node.offsetInDocument.x + node.contentsLead, y: yPos, width: node.frame.width - node.contentsLead, height: 2)

        // Should the dragged element be a child or a sibbling?
        let beginningOfContentInNode = node.contentsFrame.minX + node.offsetInDocument.x
        let makeChildOffset = beginningOfContentInNode + node.childInset
        let shouldBeChild: Bool
        if (point.x - beginningOfContentInNode) > node.childInset && shouldBeAfter {
            shouldBeChild = true
            CATransaction.disableAnimations {
                initialFrame.origin.x = makeChildOffset
                initialFrame.size.width -= node.childInset
                dragIndicator.frame = initialFrame
            }
        } else {
            shouldBeChild = false
            CATransaction.disableAnimations {
                dragIndicator.frame = initialFrame
            }
        }

        let result = DragResult(element: node, shouldBeAfter: shouldBeAfter, shouldBeChild: shouldBeChild)
        performHapticFeedback(for: result)
        previousDragResult = result
        return result
    }

    private func performHapticFeedback(for dragResult: DragResult) {
        guard dragResult != previousDragResult else { return }
        let performer = NSHapticFeedbackManager.defaultPerformer
        if let previousDragResult = previousDragResult, previousDragResult.onlyDiffersByIndentation(from: dragResult) {
            performer.perform(.levelChange, performanceTime: .drawCompleted)
        } else {
            performer.perform(.alignment, performanceTime: .drawCompleted)
        }
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if NSImage.canInit(with: sender.draggingPasteboard) {
//            self.layer?.backgroundColor = NSColor.blue.cgColor
            updateDragIndicator(at: convert(sender.draggingLocation))
            return .copy
        } else {
            return NSDragOperation()
        }
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDragIndicator(at: convert(sender.draggingLocation, from: nil))
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
//        self.layer?.backgroundColor = NSColor.white.cgColor
        updateDragIndicator(at: nil)
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) {
//        self.layer?.backgroundColor = NSColor.white.cgColor
        updateDragIndicator(at: nil)
    }

    static let maximumImageSize = 40*1024*1024

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let rootNode = rootNode,
              let fileManager = BeamFileDBManager.shared
        else { return false }
        defer {
            updateDragIndicator(at: nil)
        }
        guard let dragResult = updateDragIndicator(at: convert(sender.draggingLocation)) else {
            return false
        }

        guard let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)
        else {
            Logger.shared.logError("unable to get files from drag operation", category: .noteEditor)
            return false
        }

        let newParent: ElementNode = dragResult.shouldBeAfter ? dragResult.element : dragResult.element.previousVisibleNode(ElementNode.self) ?? rootNode
        let afterNode: ElementNode? = dragResult.shouldBeAfter ? nil : dragResult.element.previousSibbling() as? ElementNode
        for url in files.reversed() {
            guard let url = url as? URL,
                  let data = try? Data(contentsOf: url)
            else { continue }
            //Logger.shared.logInfo("File dropped: \(url) - \(data) - \(data.SHA256)")

            guard let image = NSImage(contentsOf: url)
            else {
                Logger.shared.logError("Unable to load image from url \(url)", category: .noteEditor)
                return false
            }

            if data.count > Self.maximumImageSize {
                guard let data = image.jpegRepresentation else {
                    Logger.shared.logError("Error while getting jpeg representation from NSImage", category: .noteEditor)
                    return false
                }
                if data.count > Self.maximumImageSize {
                    UserAlert.showError(message: "This image is too large for beam.", informativeText: "Please use images that are smaller than 40MB.", buttonTitle: "Cancel")
                    return false
                }
            }

            do {
                let uid = try fileManager.insert(name: url.lastPathComponent, data: data)
                let newElement = BeamElement()
                newElement.kind = .image(uid, displayInfos: MediaDisplayInfos(height: Int(image.size.height), width: Int(image.size.width), displayRatio: nil))
                rootNode.cmdManager.insertElement(newElement, inNode: newParent, afterNode: afterNode)
                try fileManager.addReference(fromNote: rootNode.elementId, element: newElement.id, to: uid)
                Logger.shared.logInfo("Added Image to note \(String(describing: rootNode.element.note)) with uid \(uid) from dropped file (\(image))", category: .noteEditor)
            } catch {
                Logger.shared.logError("Unable to insert image in FileDB \(error)", category: .fileDB)
                return false
            }
        }

        return true
    }

    // MARK: - Reordering bullet

    private var mouseMoveOrigin: CGPoint?

    func widgetDidStartMoving(_ widget: Widget, at point: CGPoint) -> Bool {
        guard canMove(widget) else { return false }
        guard let movedNode = widget as? ElementNode else { return false }

        let selectedNodesToMove = selectedNodesToMoveAlong(for: movedNode)
        for node in selectedNodesToMove {
            node.isDraggedForMove = true
        }
        focusedWidget = nil
        mouseMoveOrigin = point
        widget.isDraggedForMove = true
        return true
    }

    func widgetDidStopMoving(_ widget: Widget, at point: CGPoint) {

        defer {
            cleanupAfterDraggingWidget(widget)
        }

        let dragResult: DragResult?

        let canDrop = canDrop(widget, at: point)
        if !canDrop, let previous = previousDragResult {
            dragResult = previous
        } else if canDrop {
            dragResult = updateDragIndicator(at: point)
        } else {
            return
        }

        guard let dragResult = dragResult, let rootNode = rootNode else { return }
        guard let movedNode = widget as? ElementNode else { return }

        let newParent: ElementNode
        let index: Int
        let destinationElementIndex = dragResult.element.indexInParent ?? 0
        let selectedNodes = sortedSelectedRootsToMoveAlong(for: movedNode)

        if dragResult.shouldBeAfter && dragResult.shouldBeChild {
            newParent = dragResult.element
            index = 0
        } else {
            var previousNodeMovingOffset = 0
            // If the moving node is a sibbling of the destination, and is located before, we need to offet by one
            if isMovedNodeSibbling(movedNode, andBeforeDestinationNode: dragResult.element) {
                previousNodeMovingOffset = 1
            }
            index = destinationElementIndex + (dragResult.shouldBeAfter ? 1 : 0) - previousNodeMovingOffset
            newParent = dragResult.element.parent as? ElementNode ?? rootNode
        }

        if !selectedNodes.isEmpty {
            var offset = 0
            rootNode.cmdManager.beginGroup(with: "Multiple node move")
            let shouldIncreaseIndex = !isMovedNodeSibbling(selectedNodes.first ?? movedNode, andBeforeDestinationNode: dragResult.element) || dragResult.shouldBeChild
            for node in selectedNodes {
                rootNode.cmdManager.reparentElement(node, to: newParent, atIndex: index + offset)
                if shouldIncreaseIndex {
                    offset += 1
                }
            }
            rootNode.cmdManager.endGroup()
        } else {
            rootNode.cmdManager.reparentElement(movedNode, to: newParent, atIndex: index)
        }
    }

    func widgetMoved(_ widget: Widget, at point: CGPoint) {
        guard let mouseMoveOrigin = self.mouseMoveOrigin else { return }
        guard let movedNode = widget as? ElementNode else { return }

        let offset = CGPoint(x: point.x - mouseMoveOrigin.x, y: point.y -  mouseMoveOrigin.y)
        widget.translateForMove(offset)
        let selectedNodesToMove = selectedNodesToMoveAlong(for: movedNode)
        for node in selectedNodesToMove {
            node.translateForMove(offset)
        }

        if canDrop(widget, at: point) {
            updateDragIndicator(at: point)
        }
    }

    private func canMove(_ widget: Widget) -> Bool {
        guard widget as? ProxyNode == nil else { return false }
        return true
    }

    private func canDrop(_ widget: Widget, at point: NSPoint) -> Bool {
        guard let rootNode = rootNode else { return false }
        guard let movedNode = widget as? ElementNode else { return false }

        if let node = rootNode.widgetAt(point: CGPoint(x: point.x, y: point.y - rootNode.frame.minY)) as? ElementNode,
           !(node is ProxyNode), node.elementKind != .dailySummary,
           node !== widget,
           node.parent !== widget,
           !widget.allChildren.contains(node),
           !selectedNodesToMoveAlong(for: movedNode).contains(node) {
            return true
        }
        return false
    }

    private func cleanupAfterDraggingWidget(_ widget: Widget) {
        guard let movedNode = widget as? ElementNode else { return }
        widget.isDraggedForMove = false
        mouseMoveOrigin = nil
        updateDragIndicator(at: nil)

        for node in selectedNodesToMoveAlong(for: movedNode) {
            node.isDraggedForMove = false
        }
    }

    private func selectedNodesToMoveAlong(for initialNode: ElementNode) -> Set<ElementNode> {
        if let nodes = rootNode?.state.nodeSelection?.nodes, nodes.contains(initialNode) {
            return nodes
        } else {
            return []
        }
    }

    private func sortedSelectedRootsToMoveAlong(for initialNode: ElementNode) -> [ElementNode] {
        if let nodes = rootNode?.state.nodeSelection?.sortedRoots, nodes.contains(initialNode) {
            return nodes
        } else {
            return []
        }
    }

    private func isMovedNodeSibbling(_ movedNode: ElementNode, andBeforeDestinationNode: ElementNode) -> Bool {
        if movedNode.isSibblingWith(andBeforeDestinationNode),
           let destinationIndex = andBeforeDestinationNode.indexInParent,
            let movedElementIndex = movedNode.indexInParent,
            destinationIndex > movedElementIndex {
            return true
        }
        return false
    }

    // MARK: - Note sources

    static public let mainLayerName = "beamTextEditMainLayer"

    func addNoteSourceFrom(url: String) {
        guard let note = note as? BeamNote, let data = data else { return }
        let urlId = LinkStore.getOrCreateIdFor(url)
        note.sources.add(urlId: urlId, noteId: note.id, type: .user, sessionId: data.sessionId, activeSources: data.activeSources)
    }
    func addNoteSourceFrom(text: BeamText) {
        for range in text.noteSourceEligibleLinkRanges {
            addNoteSourceFrom(url: range.string)
        }
    }

    // MARK: - SignPost

    public static var signPost = SignPost("BeamTextEdit")
    public var sign: SignPostId!
    struct Signs {
        static let updateRoot: StaticString = "updateRoot"
        static let prepareRoot: StaticString = "prepareRoot"
        static let relayoutRoot: StaticString = "relayoutRoot"
        static let updateLayout: StaticString = "updateLayout"
        static let updateLayout_initRootNode: StaticString = "updateLayout.initRootNode"
        static let updateLayout_initLayout: StaticString = "updateLayout.initLayout"
        static let updateRoot_delayedInit: StaticString = "updateRoot.delayedInit"
    }
}
