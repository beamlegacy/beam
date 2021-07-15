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

    static let textWidth: CGFloat = 550

    var data: BeamData?
    var cardTopSpace: CGFloat {
        journalMode ? 135 : 0
    }
    var centerText = false {
        didSet {
            setupCardHeader()
        }
    }

    private var _isTodaysNote: Bool = false
    var isTodaysNote: Bool {
        _isTodaysNote
    }
    var note: BeamElement! {
        didSet {
            note?.updateNoteNamesInInternalLinks(recursive: true)
            DispatchQueue.main.async {
                self.scroll(.zero)
            }
            updateRoot(with: note)
        }
    }

    func updateRoot(with note: BeamElement) {
        guard note != rootNode?.element else { return }
        _isTodaysNote = note.note?.isTodaysNote ?? false

        clearRoot()
        rootNode = TextRoot(editor: self, element: note)
    }

    private func clearRoot() {
        if let layers = layer?.sublayers {
            for l in layers where ![cardHeaderLayer, cardTimeLayer].contains(l) {
                l.removeFromSuperlayer()
            }
        }

        for c in subviews {
            c.removeFromSuperview()
        }

        rootNode?.clearMapping() // Clear all previous references in the node tree
        rootNode = TextRoot(editor: self, element: BeamElement())
        // Remove all subsciptions:
        noteCancellables.removeAll()
    }

    private var noteCancellables = [AnyCancellable]()

    // Popover properties
    internal var cursorStartPosition = 0
    internal var popoverPrefix = 0
    internal var popoverSuffix = 0
    internal var popover: BidirectionalPopover?

    // Formatter properties
    internal var inlineFormatter: FormatterView?
    internal var formatterTargetRange: Range<Int>?
    internal var formatterTargetNode: TextNode?
    internal var isInlineFormatterHidden = true
    internal var currentTextRange: Range<Int> = 0..<0

    func addToMainLayer(_ layer: CALayer) {
        //Logger.shared.logDebug("addToMainLayer: \(layer.name)")
        self.layer?.addSublayer(layer)
    }

    let cardHeaderLayer = CALayer()
    let cardSeparatorLayer = CALayer()
    let cardTitleLayer = CATextLayer()
    let cardSideLayer = CALayer()
    let cardSideTitleLayer = CATextLayer()
    let cardTimeLayer = CATextLayer()
    let titleUnderLine = CALayer()

    private (set) var isResizing = false
    public private (set) var journalMode: Bool
    public var scrollToElementId: UUID? {
        didSet {
            guard let id = scrollToElementId,
                  let element = note.findElement(id),
                  let node = rootNode.nodeFor(element)
            else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(50))) {
                self.setHotSpot(node.frameInDocument)
                node.hightlight()
                if let w = self.window as? BeamWindow {
                    w.state.scrollToElementId = nil
                }
            }
        }
    }

    public init(root: BeamElement, journalMode: Bool) {
        self.journalMode = journalMode

        note = root

        super.init(frame: NSRect())

        setAccessibilityIdentifier("TextEdit")
        setAccessibilityLabel("Note Editor")
        setAccessibilityTitle((root as? BeamNote)?.title)

        let l = CALayer()
        self.layer = l
        l.backgroundColor = BeamColor.Generic.background.cgColor
        l.masksToBounds = false

        layer?.delegate = self
        // self.wantsLayer = true

        timer = Timer.init(timeInterval: 1.0 / 60.0, repeats: true) { [unowned self] _ in
            let now = CFAbsoluteTimeGetCurrent()
            if self.blinkTime <= now && self.hasFocus {
                self.blinkPhase.toggle()
                self.blinkTime = now + (self.blinkPhase ? self.onBlinkTime : self.offBlinkTime)
                if let focused = focusedWidget as? ElementNode {
                    focused.updateCursor()
                }

            }
        }
        RunLoop.main.add(timer, forMode: .default)

        initBlinking()
        updateRoot(with: root)
        setupSideLayer()

        registerForDraggedTypes([.fileURL])
    }

    deinit {
        timer.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        isResizing = true
        dismissPopoverOrFormatter()
    }

    public override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        isResizing = false
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = BeamColor.Generic.background.cgColor
        layer?.setNeedsDisplay()
        setupCardHeader()
        rootNode.deepInvalidateRendering()
        rootNode.deepInvalidateText()
    }

    var timer: Timer!

    var minimumWidth: CGFloat = 300 {
        didSet {
            if oldValue != minimumWidth {
                invalidateLayout()
            }
        }
    }
    var maximumWidth: CGFloat = 1024 {
        didSet {
            if oldValue != minimumWidth {
                invalidateLayout()
            }
        }
    }

    var leadingAlignment = CGFloat(160) {
        didSet {
            if oldValue != minimumWidth {
                invalidateLayout()
            }
        }
    }
    var traillingPadding = CGFloat(80) {
        didSet {
            if oldValue != minimumWidth {
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
    public var openURL: (URL, BeamElement) -> Void = { _, _ in }
    public var openCard: (UUID, UUID?) -> Void = { _, _ in }
    public var onStartEditing: () -> Void = { }
    public var onEndEditing: () -> Void = { }
    public var onStartQuery: (TextNode) -> Void = { _ in }

    public var config = TextConfig()

    var selectedTextRange: Range<Int> {
        get {
            rootNode.state.selectedTextRange
        }
        set {
            assert(newValue.lowerBound != NSNotFound)
            assert(newValue.upperBound != NSNotFound)
            rootNode.state.selectedTextRange = newValue
            reBlink()
        }
    }

    var selectedText: String {
        return rootNode.selectedText
    }

    static let bigThreshold = CGFloat(1024)
    var isBig: Bool {
        frame.width >= Self.bigThreshold
    }

    public override var frame: NSRect {
        didSet {
            let oldbig = oldValue.width >= Self.bigThreshold
            let newbig = isBig

            if oldbig != newbig {
                rootNode.deepInvalidateText()
                invalidateLayout()
            }
        }
    }

    var shouldDisableAnimationAtNextLayout = false
    func disableAnimationAtNextLayout() {
        shouldDisableAnimationAtNextLayout = true
    }
    func relayoutRoot() {
        let r = bounds
        let width = CGFloat(isBig ? frame.width - 200 - leadingAlignment : 450)
        var rect = NSRect(x: leadingAlignment, y: topOffsetActual, width: width, height: r.height)

        if centerText {
            let x = (frame.width - Self.textWidth) / 2

            rect = NSRect(x: x, y: topOffsetActual + cardTopSpace, width: textNodeWidth, height: r.height)

            if isResizing || shouldDisableAnimationAtNextLayout {
                shouldDisableAnimationAtNextLayout = false
                // Disable CALayer animation on resize
                CATransaction.disableAnimations {
                    rootNode.availableWidth = textNodeWidth
                    updateCardHearderLayer(rect)
                    if journalMode {
                        updateSideLayer(rect)
                    }
                    rootNode.setLayout(rect)
                }
            } else {
                rootNode.availableWidth = textNodeWidth
                updateCardHearderLayer(rect)
                if journalMode {
                    updateSideLayer(rect)
                }
                rootNode.setLayout(rect)
            }

        } else {
            rootNode.availableWidth = textNodeWidth
            rootNode.setLayout(rect)
        }
    }

    var textNodeWidth: CGFloat {
        return centerText ? Self.textWidth : CGFloat(isBig ? frame.width - 200 - leadingAlignment : 450)
    }

    // This is the root node of what we are editing:
    var rootNode: TextRoot!
    var cmdManager: CommandManager<Widget> {
        rootNode.cmdManager
    }

    // This is the node that the user is currently editing. It can be any node in the rootNode tree
    var focusedWidget: Widget? {
        get { rootNode.focusedWidget }
        set {
            invalidate()
            rootNode.focusedWidget = newValue
            invalidate()
        }
    }
    var mouseHandler: Widget? {
        get { rootNode.mouseHandler }
        set { rootNode.mouseHandler = newValue }
    }

    var topOffset: CGFloat = 28 { didSet { invalidateLayout() } }
    var footerHeight: CGFloat = 60 { didSet { invalidateLayout() } }
    var topOffsetActual: CGFloat {
        config.keepCursorMidScreen ? visibleRect.height / 2 : topOffset
    }

    func setupCardHeader() {
        guard let cardNote = note as? BeamNote else { return }

        cardTitleLayer.name = "cardTitleLayer"
        cardTitleLayer.enableAnimations = false
        cardTimeLayer.enableAnimations = false
        cardHeaderLayer.enableAnimations = false
        cardHeaderLayer.isHidden = !showTitle

        cardTitleLayer.foregroundColor = BeamColor.Generic.text.cgColor
        cardTitleLayer.font = BeamFont.medium(size: 26).nsFont
        cardTitleLayer.fontSize = 26 // TODO: Change later (isBig ? 30 : 26)
        cardTitleLayer.string = cardNote.title

        if journalMode {
            titleUnderLine.frame = NSRect(x: 0, y: cardTitleLayer.preferredFrameSize().height, width: cardTitleLayer.preferredFrameSize().width, height: 2)
            titleUnderLine.backgroundColor = BeamColor.AlphaGray.cgColor
            titleUnderLine.isHidden = true
            cardTitleLayer.addSublayer(titleUnderLine)
        }

        cardHeaderLayer.addSublayer(cardTitleLayer)
        addToMainLayer(cardHeaderLayer)
    }

    private var cardHeaderPosY: CGFloat {
        return journalMode ? 63 : 127
    }

    private var cardTimePosY: CGFloat {
        return journalMode ? 44 : 104
    }

    func updateCardHearderLayer(_ rect: NSRect) {
        let cardHeaderPosX = rect.origin.x + 17
        cardHeaderLayer.frame = CGRect(origin: CGPoint(x: cardHeaderPosX, y: cardHeaderPosY), size: NSSize(width: rect.width, height: cardTitleLayer.preferredFrameSize().height))
        cardTitleLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: NSSize(width: cardTitleLayer.preferredFrameSize().width, height: cardTitleLayer.preferredFrameSize().height))
    }

    func setupSideLayer() {
        guard let cardNote = note as? BeamNote else { return }
        cardSideLayer.enableAnimations = true

        cardSideTitleLayer.foregroundColor = BeamColor.Generic.text.cgColor
        cardSideTitleLayer.font = BeamFont.semibold(size: 0).nsFont
        cardSideTitleLayer.fontSize = 15 // TODO: Change later (isBig ? 30 : 26)
        cardSideTitleLayer.string = isBig ? cardNote.title : BeamDate.str(for: cardNote.creationDate, with: .short)
        cardSideTitleLayer.name = "cardSideTitleLayer"

        cardSideLayer.addSublayer(cardSideTitleLayer)
        cardSideLayer.opacity = 0

        addToMainLayer(cardSideLayer)
    }

    func updateSideLayer(_ rect: CGRect) {
        guard let cardNote = note as? BeamNote else { return }
        cardSideTitleLayer.string = isBig ? cardNote.title : BeamDate.str(for: cardNote.creationDate, with: .short)
        let sideLayerPos = CGPoint(x: cardHeaderLayer.frame.origin.x - cardSideTitleLayer.preferredFrameSize().width - 46.5, y: topOffsetActual + cardTopSpace + sideLayerOffset)
        cardSideLayer.frame = CGRect(origin: sideLayerPos, size: NSSize(width: cardSideLayer.preferredFrameSize().width, height: cardSideLayer.preferredFrameSize().height))
        cardSideTitleLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: NSSize(width: cardSideTitleLayer.preferredFrameSize().width, height: cardSideTitleLayer.preferredFrameSize().height))
    }

    var sideLayerOffset: CGFloat = .zero {
        didSet {
            invalidateLayout()
        }
    }

    func updateSideLayerVisibility(hide: Bool) {
        if !hide && cardSideLayer.opacity == 0 || hide && cardSideLayer.opacity == 1 {
            let oldValue = cardSideLayer.opacity
            let newValue: Float = oldValue == 0 ? 1 : 0
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = oldValue
            opacityAnimation.toValue = newValue
            opacityAnimation.duration = 0.25
            cardSideLayer.add(opacityAnimation, forKey: "opacity")
            cardSideLayer.opacity = newValue
        }
    }

    func updateSideLayerPosition(y: CGFloat, scrollingDown: Bool) {
        sideLayerOffset += y
        sideLayerOffset = sideLayerOffset < 0 ? 0 : sideLayerOffset
    }

    override public var intrinsicContentSize: NSSize {
        rootNode.availableWidth = textNodeWidth
        let height = centerText ?
            rootNode.idealSize.height + topOffsetActual + footerHeight + cardTopSpace :
            rootNode.idealSize.height + topOffsetActual + footerHeight
        return NSSize(width: textNodeWidth, height: height)
    }

    private var dragging = false
    func startSelectionDrag() { dragging = true }
    func stopSelectionDrag() { dragging = false }

    public func setHotSpot(_ spot: NSRect) {
        guard !dragging else { return }
        guard !self.visibleRect.contains(spot) else { return }
        _ = scrollToVisible(spot)
    }

    public func invalidateLayout() {
        guard !inRelayout else { return }
        invalidateIntrinsicContentSize()
        invalidate()
        if let stack = superview as? JournalStackView {
            stack.invalidateLayout()
        }
    }

    public func invalidate() {
        setNeedsDisplay(bounds)
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return rootNode.hasMarkedText()
    }

    public func unmarkText() {
        rootNode.unmarkText()
    }

    public func insertText(string: String, replacementRange: Range<Int>?) {
        guard let node = focusedWidget as? ElementNode, !node.readOnly else { return }
        defer { inputDetectorLastInput = string }
        guard preDetectInput(string) else { return }
        rootNode.insertText(string: string, replacementRange: replacementRange)
        postDetectInput(string)
        reBlink()
        updateInlineFormatterView(isKeyEvent: true)
        updatePopover()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        return rootNode.firstRect(forCharacterRange: range)
    }

    public var enabled = true

    @Published var hasFocus = false

    public override func becomeFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = true
        invalidate()
        onStartEditing()
        return true
    }

    public override func resignFirstResponder() -> Bool {
        blinkPhase = true
        hasFocus = false
        onEndEditing()

        guard (inlineFormatter as? HyperlinkFormatterView) == nil else { return super.resignFirstResponder() }

        rootNode.cancelSelection()
        rootNode.cancelNodeSelection()
        (focusedWidget as? TextNode)?.invalidateText() // force removing the syntax highlighting
        focusedWidget?.invalidate()
        focusedWidget?.onUnfocus()
        focusedWidget = nil
        if activateOnLostFocus { activated() }

        cancelInternalLink()
        dismissPopover()
        showOrHideInlineFormatter(isPresent: false)
        return true
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func pressEnter(_ option: Bool, _ command: Bool, _ shift: Bool, _ ctrl: Bool) {
        guard let node = focusedWidget as? ElementNode else { return }

        if option || shift {
            rootNode.insertNewline()
            hideInlineFormatter()
        } else if ctrl, let textNode = node as? TextNode, case let .check(checked) = node.elementKind {
            cmdManager.formatText(in: textNode, for: .check(!checked), with: nil, for: nil, isActive: false)
        } else if let popover = popover {
            popover.selectItem()
            return
        } else if inlineFormatter?.pressEnter() != true {
            hideInlineFormatter()
            cmdManager.beginGroup(with: "Insert line")
            defer {
                cmdManager.endGroup()
            }

            guard let node = node as? TextNode, (node as? BlockReferenceNode) == nil else {
                rootNode.insertElementNearNonTextElement()
                return
            }
            if node.text.isEmpty && node.isEmpty && node.parent !== rootNode {
                rootNode.decreaseIndentation()
                return
            }

            let insertAsChild = node.parent as? BreadCrumb != nil || node._displayedElement != nil

            if !rootNode.selectedTextRange.isEmpty {
                rootNode.cmdManager.deleteText(in: node, for: rootNode.selectedTextRange)
            }

            let range = rootNode.cursorPosition ..< node.text.count
            let str = node.text.extract(range: range)
            if !range.isEmpty {
                cmdManager.deleteText(in: node, for: range)
            }

            let newElement = BeamElement(str)
            if insertAsChild {
                if let parent = node._displayedElement {
                    cmdManager.insertElement(newElement, inElement: parent, afterElement: nil)
                } else {
                    cmdManager.insertElement(newElement, inNode: node, afterElement: nil)
                }
            } else {
                guard let parent = node.parent as? ElementNode else { return }
                let children = node.element.children

                cmdManager.insertElement(newElement, inNode: parent, afterNode: node)
                guard let newElement = node.nodeFor(newElement)?.element else { return }

                // reparent all children of node to newElement
                for child in children {
                    cmdManager.reparentElement(child, to: newElement, atIndex: newElement.children.count)
                }

            }

            if let toFocus = node.nodeFor(newElement) {
                cmdManager.focusElement(toFocus, cursorPosition: 0)
            }
        }
    }

    var shift: Bool { NSEvent.modifierFlags.contains(.shift) }
    var option: Bool { NSEvent.modifierFlags.contains(.option) }
    var control: Bool { NSEvent.modifierFlags.contains(.control) }
    var command: Bool { NSEvent.modifierFlags.contains(.command) }

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    override open func keyDown(with event: NSEvent) {
        if self.hasFocus {
            NSCursor.setHiddenUntilMouseMoves(true)

            switch event.keyCode {
            case KeyCode.escape.rawValue:
                rootNode.cancelSelection()
                dismissPopoverOrFormatter()
                return
            case KeyCode.enter.rawValue:
                if command && rootNode.state.nodeSelection == nil, let node = rootNode.focusedWidget as? TextNode {
                    onStartQuery(node)
                    return
                }
            default:
                break
            }

            if let ch = event.charactersIgnoringModifiers {
                switch ch.lowercased() {
                case "1", "2":
                    if command && option || shift && command && option {
                        cancelPopover()
                        toggleHeading(Int(ch) ?? 1)
                        return
                    }
                case "[":
                    if command {
                        cancelPopover()
                        rootNode.decreaseIndentation()
                        return
                    }
                case "]":
                    if command {
                        cancelPopover()
                        rootNode.increaseIndentation()
                        return
                    }
                case "b" :
                    if command {
                        cancelPopover()
                        toggleBold()
                        return
                    }
                case "c":
                    if option && command {
                        cancelPopover()
                        toggleCode()
                        return
                    }
                case "i":
                    if command {
                        cancelPopover()
                        toggleEmphasis()
                        return
                    }
                case "k":
                    if shift && command {
                        toggleBiDirectionalLink()
                        return
                    }

                    if command {
                        cancelPopover()
                        toggleLink()
                        return
                    }
                case "l":
                    if shift && command {
                        cancelPopover()
                        toggleUnorderedAndOrderedList()
                        return
                    }
                case "u":
                    if shift && command {
                        cancelPopover()
                        toggleQuote()
                        return
                    }

                    if command && rootNode.textIsSelected {
                        toggleUnderline()
                        return
                    }
                case "t":
                    if option && command {
                        cancelPopover()
                        toggleTodo()
                        return
                    }
                case "y":
                    if command {
                        cancelPopover()
                        toggleStrikeThrough()
                        return
                    }
                case "d":
                    if control, shift {
                        dumpWidgetTree()
                        dumpLayers()
                        return
                    }

                case "s":
                    if command, shift {
                        let encoder = JSONEncoder()
                        if let data = try? encoder.encode(note) {
                            if let str = String(data: data, encoding: .utf8) {
                                //swiftlint:disable:next print
                                print("JSON Dump of the current note:\n\n\(str)\n")
                            }
                        }
                        return
                    }
                default:
                    break
                }
            }
        }

        inputContext?.handleEvent(event)
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
            rootNode.setMarkedText(string: str, selectedRange: selection, replacementRange: replacement)
        } else if let str = string as? NSAttributedString {
            rootNode.setMarkedText(string: str.string, selectedRange: selection, replacementRange: replacement)
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
        guard let range = rootNode.markedTextRange else {
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
        if let firstResponder = window?.firstResponder, let undoManager = firstResponder.undoManager, firstResponder != self {
            undoManager.undo()
            return
        }
        _ = rootNode.note?.cmdManager.undo(context: rootNode.cmdContext)
    }

    @IBAction func redo(_ sender: Any) {
        if let firstResponder = window?.firstResponder, let undoManager = firstResponder.undoManager, firstResponder != self {
            undoManager.redo()
            return
        }
        _ = rootNode.note?.cmdManager.redo(context: rootNode.cmdContext)
    }

    // MARK: Input detector properties
    // State to detect shortcuts: @ / [[ ]]
    internal var inputDetectorState: Int = 0
    internal var inputDetectorEnabled: Bool { inputDetectorState >= 0 }
    internal var inputDetectorLastInput: String = ""

    // MARK: Paste properties
    internal let supportedCopyTypes: [NSPasteboard.PasteboardType] = [.noteDataHolder, .bTextHolder, .rtf, .string]
    internal let supportedPasteObjects = [BeamNoteDataHolder.self, BeamTextHolder.self, NSAttributedString.self, NSString.self]

    func initBlinking() {
        let defaults = UserDefaults.standard
        let von = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOn")
        onBlinkTime = von == 0 ? onBlinkTime : von * 1000
        let voff = defaults.double(forKey: "NSTextInsertionPointBlinkPeriodOff")
        offBlinkTime = voff == 0 ? offBlinkTime : voff * 1000
    }

    func reBlink() {
        blinkPhase = true
        blinkTime = CFAbsoluteTimeGetCurrent() + onBlinkTime
        focusedWidget?.invalidate()
    }

    public func positionAt(point: NSPoint) -> Int {
        guard let node = focusedWidget as? TextNode else { return 0 }
        let fid = node.frameInDocument
        return node.positionAt(point: NSPoint(x: point.x - fid.minX, y: point.y - fid.minY))
    }

    // MARK: - Scroll Event
    public override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if popover != nil { cancelPopover() }
    }

    // MARK: - Mouse Event
    override public func updateTrackingAreas() {
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeInActiveApp, .mouseEnteredAndExited, .cursorUpdate, .enabledDuringMouseDrag, .inVisibleRect], owner: self, userInfo: nil))
    }

    var mouseDownPos: NSPoint?
    private func handleMouseDown(event: NSEvent) {
        guard !(inputContext?.handleEvent(event) ?? false) else { return }
        reBlink()
        rootNode.cancelNodeSelection() // TODO: change this to handle manipulating the node selection with the mouse
        if self.mouseDownPos != nil {
            self.mouseDownPos = nil
        }
        self.mouseDownPos = convert(event.locationInWindow)
        let info = MouseInfo(rootNode, mouseDownPos ?? .zero, event)
        mouseHandler = rootNode.dispatchMouseDown(mouseInfo: info)
        if mouseHandler != nil { cursorUpdate(with: event) }
    }

    public override func rightMouseDown(with event: NSEvent) {
        handleMouseDown(event: event)
    }

    public override func mouseDown(with event: NSEvent) {
        //       window?.makeFirstResponder(self)
        handleMouseDown(event: event)
    }

    let scrollXBorder = CGFloat(20)
    let scrollYBorderUp = CGFloat(10)
    let scrollYBorderDown = CGFloat(90)

    public func setHotSpotToCursorPosition() {
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
        guard !(inputContext?.handleEvent(event) ?? false) else { return }

        //        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow)
        startSelectionDrag()
        _ = rootNode.dispatchMouseDragged(mouseInfo: MouseInfo(rootNode, point, event))
        cursorUpdate(with: event)
        mouseDraggedUpdate(with: event)
        autoscroll(with: event)
    }

    func convert(_ point: NSPoint) -> NSPoint {
        return self.convert(point, from: nil)
    }

    override public func mouseMoved(with event: NSEvent) {
        if journalMode {
            let titleCoord = cardTitleLayer.convert(event.locationInWindow, from: nil)
            titleUnderLine.isHidden = !cardTitleLayer.contains(titleCoord)
            if cardTitleLayer.contains(titleCoord) {
                let cursor: NSCursor = .pointingHand
                cursor.set()
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
        guard let startPos = mouseDownPos else { return }
        let eventPoint = convert(event.locationInWindow)
        let widgets = rootNode.getWidgetsBetween(startPos, eventPoint)

        if let selection = rootNode?.state.nodeSelection, let focussedNode = focusedWidget as? ElementNode {
            var textNodes = widgets.compactMap { $0 as? ElementNode }
            if eventPoint.y < startPos.y {
                textNodes = textNodes.reversed()
            }
            selection.start = focussedNode
            selection.append(focussedNode)
            for textNode in textNodes {
                if !selection.nodes.contains(textNode) {
                    selection.append(textNode)
                }
            }
            for selectedNode in selection.nodes {
                if !textNodes.contains(selectedNode) && selectedNode != focussedNode {
                    selection.remove(selectedNode)
                }
            }
            if textNodes.isEmpty {
                selection.end = focussedNode
            } else {
                guard let lastNode = textNodes.last else { return }
                selection.end = lastNode
            }
        } else {
            if widgets.count > 0 {
                _ = rootNode?.startNodeSelection()
            }
            return
        }
    }

    public override func cursorUpdate(with event: NSEvent) {
        let point = convert(event.locationInWindow)
        let views = rootNode.getWidgetsAt(point, point)
        let cursors = views.compactMap { $0.cursor }
        let cursor = cursors.last ?? .arrow
        cursor.set()
        dispatchHover(Set<Widget>(views.compactMap { $0 as? Widget }))
    }

    func dispatchHover(_ widgets: Set<Widget>) {
        rootNode.dispatchHover(widgets)
    }

    override public func mouseUp(with event: NSEvent) {
        guard !(inputContext?.handleEvent(event) ?? false) else { return }
        stopSelectionDrag()

        if journalMode {
            let titleCoord = cardTitleLayer.convert(event.locationInWindow, from: nil)
            if cardTitleLayer.contains(titleCoord) {
                guard let cardNote = note as? BeamNote else { return }
                self.openCard(cardNote.id, nil)
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

    public override var acceptsFirstResponder: Bool { true }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        guard let window = newWindow else {
            _ = self.resignFirstResponder()
            self.clearRoot()
            return
        }
        window.acceptsMouseMovedEvents = true
        rootNode.contentsScale = window.backingScaleFactor

        cardTitleLayer.contentsScale = window.backingScaleFactor
        cardTimeLayer.contentsScale = window.backingScaleFactor
        cardSideTitleLayer.contentsScale = window.backingScaleFactor
    }

    var onBlinkTime: Double = 0.7
    var offBlinkTime: Double = 0.5
    var blinkTime: Double = CFAbsoluteTimeGetCurrent()
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

    let documentManager = DocumentManager(coreDataManager: CoreDataManager.shared)

    @IBAction func save(_ sender: Any?) {
        Logger.shared.logInfo("Save document!", category: .noteEditor)
        rootNode.note?.save(documentManager: documentManager)
    }

    internal func showBidirectionalPopover(mode: PopoverMode, prefix: Int, suffix: Int, initialText: String? = nil) {
        // DispatchQueue to init the popover after the node is initialized
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let cursorPosition = self.rootNode.cursorPosition - prefix

            self.popoverPrefix = prefix
            self.popoverSuffix = suffix
            if self.rootNode.textIsSelected {
                let range = self.rootNode.selectedTextRange
                self.cursorStartPosition = range.lowerBound
                self.rootNode.cancelSelection()
                self.rootNode.cursorPosition = range.upperBound
            } else {
                self.cursorStartPosition = cursorPosition
            }
            self.initPopover(mode: mode, initialText: initialText)
            self.updatePopover()
        }
    }

    func initInlineTextFormatter() {
        guard let node = focusedWidget as? TextNode else { return }

        if inlineFormatter == nil && popover == nil {
            currentTextRange = node.selectedTextRange
            initInlineFormatterView()
        }
    }

    func showInlineFormatterOnKeyEventsAndClick(isKeyEvent: Bool = false) {
        initInlineTextFormatter()
        updateInlineFormatterView(isKeyEvent: isKeyEvent)

        if isInlineFormatterHidden {
            showOrHideInlineFormatter(isPresent: true)
        }
    }

    func updateInlineFormatterOnDrag(isDragged: Bool = false) {
        initInlineTextFormatter()
        updateInlineFormatterView(isDragged: isDragged)
    }

    func hideInlineFormatter() {
        guard inlineFormatter != nil else { return }
        showOrHideInlineFormatter(isPresent: false)
    }

    func hideFloatingView() {
        dismissPopover()
        dismissFormatterView(inlineFormatter)
    }

    func dismissPopoverOrFormatter() {
        if popover != nil {
            if popoverPrefix > 0 { cancelInternalLink() }
            dismissPopover()
        }

        if inlineFormatter != nil {
            hideInlineFormatter()
        }
    }

    @IBAction func selectAllHierarchically(_ sender: Any?) {
        rootNode.selectAllNodesHierarchically()
    }

    func dumpWidgetTree() {
        rootNode.dumpWidgetTree()
    }

    func dumpSubLayers(_ layer: CALayer, _ level: Int) {
        // swiftlint:disable print
        let tabs = String.tabs(level)
        for (i, l) in (layer.sublayers ?? []).enumerated() {
            print("\(tabs)\(i) - '\(l.name ?? "unnamed")' - pos \(l.position) - bounds \(l.bounds) \(l.isHidden ? "[HIDDEN]" : "")")
            dumpSubLayers(l, level + 1)
        }
        // swiftlint:enable print
    }

    func dumpLayers() {
        // swiftlint:disable print
        print("================")
        print("Dumping editor \(layer?.sublayers?.count ?? 0) layers:")
        if let layer = layer {
            dumpSubLayers(layer, 0)
        }
        print("================")
        // swiftlint:enable print
    }

    public override func accessibilityChildren() -> [Any]? {
        let ch = rootNode.allVisibleChildren
        return ch
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

        rootNode.moveLeft()

        if popover != nil {
            updatePopover(with: .moveLeft)
        }

        if inlineFormatter != nil {
            hideInlineFormatter()
        }
    }

    override public func moveRight(_ sender: Any?) {
        if control && option && command {
            guard let node = focusedWidget as? ElementNode else { return }
            node.unfold()
            return
        }

        if popover != nil {
            guard let node = focusedWidget as? TextNode,
                  node.text.text.count > rootNode.cursorPosition else { return }
        }

        rootNode.moveRight()

        if popover != nil {
            updatePopover(with: .moveRight)
        }

        if inlineFormatter != nil {
            hideInlineFormatter()
        }

    }

    override public func moveLeftAndModifySelection(_ sender: Any?) {
        rootNode.moveLeftAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
    }

    override public func moveWordRight(_ sender: Any?) {
        rootNode.moveWordRight()
    }

    override public func moveWordLeft(_ sender: Any?) {
        rootNode.moveWordLeft()
    }

    override public func moveWordRightAndModifySelection(_ sender: Any?) {
        rootNode.moveWordRightAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveWordLeftAndModifySelection(_ sender: Any?) {
        rootNode.moveWordLeftAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveRightAndModifySelection(_ sender: Any?) {
        rootNode.moveRightAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
    }

    override public func moveToBeginningOfLine(_ sender: Any?) {
        rootNode.moveToBeginningOfLine()

        if popover != nil {
            dismissPopoverOrFormatter()
        }
    }

    override public func moveToEndOfLine(_ sender: Any?) {
        rootNode.moveToEndOfLine()
        detectTextFormatterType()
    }

    override public func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        rootNode.moveToBeginningOfLineAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        rootNode.moveToEndOfLineAndModifySelection()
        showInlineFormatterOnKeyEventsAndClick()
    }

    override public func moveUp(_ sender: Any?) {
        if popover != nil {
            updatePopover(with: .moveUp)
        } else if inlineFormatter?.moveUp() != true {
            rootNode.moveUp()
            hideInlineFormatter()
        }
    }

    override public func moveDown(_ sender: Any?) {
        if popover != nil {
            updatePopover(with: .moveDown)
        } else if inlineFormatter?.moveDown() != true {
            rootNode.moveDown()
            hideInlineFormatter()
        }
    }

    override public func selectAll(_ sender: Any?) {
        cancelPopover(leaveTextAsIs: true)
        rootNode.selectAll()
        if rootNode.state.nodeSelection?.nodes.count ?? 0 <= 1 {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        } else {
            hideInlineFormatter()
        }
    }

    override public func moveUpAndModifySelection(_ sender: Any?) {
        cancelPopover()
        rootNode.moveUpAndModifySelection()
        if rootNode.state.nodeSelection?.nodes.count ?? 0 <= 1 {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

    override public func moveDownAndModifySelection(_ sender: Any?) {
        cancelPopover()
        rootNode.moveDownAndModifySelection()
        if rootNode.state.nodeSelection?.nodes.count ?? 0 <= 1 {
            showInlineFormatterOnKeyEventsAndClick(isKeyEvent: true)
        }
    }

//    override public func scrollPageUp(_ sender: Any?) {
//    }
//
//    override public func scrollPageDown(_ sender: Any?) {
//    }
//
//    override public func scrollLineUp(_ sender: Any?) {
//    }
//
//    override public func scrollLineDown(_ sender: Any?) {
//    }
//
//    override public func scrollToBeginningOfDocument(_ sender: Any?) {
//    }
//
//    override public func scrollToEndOfDocument(_ sender: Any?) {
//    }

        /* Graphical Element transposition */

//    override public func transpose(_ sender: Any?) {
//    }
//
//    override public func transposeWords(_ sender: Any?) {
//    }

        /* Selections */

    override public func selectParagraph(_ sender: Any?) {
        rootNode.selectAllNodesHierarchically()
    }

    override public func selectLine(_ sender: Any?) {
    }

    override public func selectWord(_ sender: Any?) {
    }

        /* Insertions and Indentations */

    override public func indent(_ sender: Any?) {
        rootNode.increaseIndentation()
    }

    override public func insertTab(_ sender: Any?) {
        rootNode.increaseIndentation()
    }

    override public func insertBacktab(_ sender: Any?) {
        rootNode.decreaseIndentation()
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
        rootNode.deleteForward()
        updatePopover(with: .deleteForward)

        guard let node = focusedWidget as? TextNode else { return }
        if node.text.isEmpty || !rootNode.textIsSelected { hideInlineFormatter() }
        detectTextFormatterType()
    }

    override public func deleteBackward(_ sender: Any?) {
        rootNode.deleteBackward()
        updatePopover(with: .deleteBackward)

        updateInlineFormatterView(isKeyEvent: true)
        if rootNode.cursorPosition == formatterTargetRange?.lowerBound { hideInlineFormatter() }
//        guard let node = focusedWidget as? TextNode else { return }
//        if node.text.isEmpty || !rootNode.textIsSelected { hideInlineFormatter() }
        detectTextFormatterType()
    }

//    override public func deleteBackwardByDecomposingPreviousCharacter(_ sender: Any?) {
//    }

//    override public func deleteWordForward(_ sender: Any?) {
//    }
//
//    override public func deleteWordBackward(_ sender: Any?) {
//    }
//
//    override public func deleteToBeginningOfLine(_ sender: Any?) {
//    }
//
//    override public func deleteToEndOfLine(_ sender: Any?) {
//    }
//
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
        cancelPopover(leaveTextAsIs: true)
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

    // Drag and drop:
    var dragIndicator = CALayer()
//    weak var lastDragNode: ElementNode?
    @discardableResult private func updateDragIndicator(at point: CGPoint?) -> (ElementNode, Bool)? {
        guard let point = point,
              let node = rootNode.widgetAt(point: CGPoint(x: point.x, y: point.y - rootNode.frame.minY)) as? ElementNode
        else {
            dragIndicator.isHidden = true
            return nil
        }

        if dragIndicator.superlayer == nil {
            layer?.addSublayer(dragIndicator)
        }
        dragIndicator.backgroundColor = .black
        dragIndicator.borderWidth = 0
        dragIndicator.isHidden = false
        if point.y < (node.offsetInDocument.y + node.contentsFrame.height / 2) {
            dragIndicator.frame = CGRect(x: rootNode.frame.minX, y: node.offsetInDocument.y, width: rootNode.frame.width, height: 1)
            return (node, false)
        } else {
            dragIndicator.frame = CGRect(x: rootNode.frame.minX, y: node.offsetInDocument.y + node.contentsFrame.maxY, width: rootNode.frame.width, height: 1)
            return (node, true)
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

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer {
            updateDragIndicator(at: nil)
        }
        guard let (element, after) = updateDragIndicator(at: convert(sender.draggingLocation)) else {
            return false
        }

        guard let files = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil)
        else {
            Logger.shared.logError("unable to get files from drag operation", category: .noteEditor)
            return false
        }

        let newParent: ElementNode = after ? element : element.previousVisibleNode(ElementNode.self) ?? rootNode
        let afterNode: ElementNode? = after ? nil : element.previousSibbling() as? ElementNode
        for url in files.reversed() {
            guard let url = url as? URL,
                  let data = try? Data(contentsOf: url)
            else { continue }
            //Logger.shared.logInfo("File dropped: \(url) - \(data) - \(data.MD5)")

            let uid = data.MD5
            do {
                try self.data?.fileDB.insert(name: url.lastPathComponent, uid: uid, data: data, type: "")
            } catch let error {
                Logger.shared.logError("Error while inserting file in database \(error)", category: .noteEditor)
            }

            guard let image = NSImage(contentsOf: url)
            else {
                Logger.shared.logError("Unable to load image from url \(url)", category: .noteEditor)
                return false
            }

            // swiftlint:disable:next print
            let newElement = BeamElement()
            newElement.kind = .image(uid)
            rootNode.cmdManager.insertElement(newElement, inNode: newParent, afterNode: afterNode)
            Logger.shared.logInfo("Added Image to note \(String(describing: rootNode.element.note)) with uid \(uid) from dropped file (\(image))", category: .noteEditor)
        }

        return true
    }
}
