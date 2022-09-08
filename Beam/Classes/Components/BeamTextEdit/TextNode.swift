//
//  TextNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 07/10/2020.
//

import Foundation
import AppKit
import NaturalLanguage
import Combine
import BeamCore

public class TextNode: ElementNode {
    var textFrame: TextFrame? {
        didSet {
            guard let textFrame = textFrame else { return }
            let layerTree = textFrame.layerTree
            let textLayer = Layer(name: "text", layer: layerTree)
            addLayer(textLayer, origin: CGPoint(x: contentsLead, y: 0))
        }
    }
    var emptyTextFrame: TextFrame?

    var mouseDownLocation = NSPoint.zero
    var mouseIsDragged = false
    var lastHoverMouseInfo: MouseInfo?
    var interlineFactor: CGFloat {
        switch elementKind {
        case .heading:
            return PreferencesManager.editorLineHeightHeading
        default:
            return PreferencesManager.editorLineHeightMultipleLine
        }
    }

    static func fontSizeFor(kind: ElementKind) -> CGFloat {
        switch kind {
        case .heading(let level):
            switch level {
            case 1:
                return PreferencesManager.editorFontSizeHeadingOne
            case 2...:
                return PreferencesManager.editorFontSizeHeadingTwo
            default:
                return PreferencesManager.editorFontSize
            }
        default:
            return PreferencesManager.editorFontSize
        }
    }

    var fontSize: CGFloat {
        Self.fontSizeFor(kind: elementKind)
    }

    static let cmdEnterLayer = "CmdEnterLayer"

    override var parent: Widget? {
        didSet {
            guard parent != oldValue, parent != nil else { return }
            updateTextChildren(elements: displayedElement.children)
        }
    }

    override var availableWidth: CGFloat {
        didSet {
            if availableWidth != oldValue {
                updateChildren()
                updateTextFrame()
                invalidatedRendering = true
                computeRendering()
            }
        }
    }

    var text: BeamText {
        get { displayedElement.text }
        set {
            guard displayedElement.text != newValue else { return }

            if newValue.isEmpty { updateActionLayerVisibility(hidden: true) }

            displayedElement.text = newValue
        }
    }

    var textLayer: Layer? {
        self.layers["text"]
    }

    var placeholder = BeamText() {
        didSet {
            guard oldValue != text || text.isEmpty else { return }
            invalidateText()
        }
    }

    override var strippedText: String {
        text.text
    }

    override var fullStrippedText: String {
        children.reduce(text.text) { partial, node -> String in
            guard let node = node as? TextNode else { return partial }
            return partial + " " + node.fullStrippedText
        }
    }

    var _language: NLLanguage?
    var language: NLLanguage? {
        if let l = _language {
            return l
        }

        if let root = root {
            _language = NLLanguageRecognizer.dominantLanguage(for: root.fullStrippedText)
        }
        return _language
    }

    var _attributedString: NSAttributedString?
    var attributedString: NSAttributedString {
        if _attributedString == nil {
            _attributedString = buildAttributedString()
        }
        return _attributedString!
    }

    var selectedTextRange: Range<Int> { root?.selectedTextRange ?? 0..<0 }
    var markedTextRange: Range<Int>? { root?.markedTextRange }

    override var firstLineHeight: CGFloat {
        let textFrame = emptyTextFrame ?? textFrame
        return textFrame?.lines.first?.bounds.height ?? CGFloat(fontSize * interlineFactor)
    }

    override var firstLineBaseline: CGFloat {
        let textFrame = emptyTextFrame ?? self.textFrame
        if let firstLine = textFrame?.lines.first {
            let h = firstLine.typographicBounds.ascent
            return CGFloat(h) + firstLine.frame.minY
        }
        let f = BeamText.font(fontSize)
        return f.ascender
    }

    private var debounceClickTimer: Timer?
    private var actionLayerIsHovered = false

    private let debounceClickInterval = 0.23
    var actionLayerPadding = CGFloat(11)

    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    override func buildTextChildren(elements: [BeamElement]) -> [Widget] {
        guard isInNodeProviderTree else { return [] }
        return elements.map { childElement -> ElementNode in
            nodeFor(childElement, withParent: self)
        }
    }

    override func updateTextChildren(elements: [BeamElement]) {
        children = buildTextChildren(elements: elements)
    }

    // MARK: - Initializer

    override init(parent: Widget, element: BeamElement, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        super.init(parent: parent, element: element, nodeProvider: nodeProvider, availableWidth: availableWidth)

        setupTextNode()
    }

    override init(editor: BeamTextEdit, element: BeamElement, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        super.init(editor: editor, element: element, nodeProvider: nodeProvider, availableWidth: availableWidth)

        setupTextNode()
    }

    func setupTextNode() {
        setAccessibilityLabel("TextNode")
        setAccessibilityRole(.textArea)

        initTextPadding()
        observeNoteTitles()
    }

    // MARK: - Setup UI
    private func initTextPadding() {
        textPadding = textPadding(elementKind: elementKind)
    }

    // MARK: - Setup UI

    override func setupAccessibility() {
        super.setupAccessibility()
        setAccessibilityLabel("TextNode")
        setAccessibilityRole(.textArea)
    }

    private func observeNoteTitles() {
        BeamData.shared.$renamedNote.dropFirst().sink { [unowned self] (noteId, previousName, newName) in
            Logger.shared.logInfo("Note '\(previousName)' renamed to '\(newName)' [\(noteId)]")
            if self.elementText.internalLinks.contains(noteId) {
               self.unproxyElement.updateNoteNamesInInternalLinks(recursive: true)
            }
        }.store(in: &scope)
    }

    override public func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        updateSelection()
        updateDecorations()
    }

    func buildMarkeeShape(_ start: Int, _ end: Int) -> CGPath? {
        guard let textFrame = textFrame else { return nil }

        let path = CGMutablePath()
        let startLine = lineAt(index: start)!
        let endLine = lineAt(index: end)!
        let lineCount = textFrame.lines.count
        guard lineCount > startLine, lineCount > endLine else { return nil }
        let line1 = textFrame.lines[startLine]
        let line2 = textFrame.lines[endLine]
        let xStart = offsetAt(index: start)
        let xEnd = offsetAt(index: end)

        if startLine == endLine {
            // Selection begins and ends on the same line:
            let markRect = NSRect(x: xStart, y: line1.frame.minY, width: xEnd - xStart, height: line1.bounds.height)
            path.addRect(markRect)
        } else {
            let markRect1 = NSRect(x: xStart, y: line1.frame.minY, width: textFrame.frame.width - xStart, height: line2.frame.minY - line1.frame.minY )
            path.addRect(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: textPadding.left, y: line1.frame.maxY, width: textFrame.frame.width - textPadding.left, height: line2.frame.minY - line1.frame.maxY)
                path.addRect(markRect2)
            }

            let markRect3 = NSRect(x: textPadding.left, y: line1.frame.maxY, width: xEnd - textPadding.left, height: CGFloat(line2.frame.maxY - line1.frame.maxY) + 1)
            path.addRect(markRect3)
        }

        return path
    }

    override func updateLayout() {
        guard let editor = self.editor else { return }
        super.updateLayout()
        // Disable action layer update to avoid motion glitch
        // when the global layer width is changed
        updateActionLayer(animate: !editor.isResizing)
    }

    var invalidateTextDispatched = false

    public func invalidateTextAsync() {
        if !invalidateTextDispatched {
            invalidateTextDispatched = true
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.invalidateTextDispatched else { return }
                self.invalidateTextDispatched = false
                self.invalidateText()
            }
        }
    }

    var invalidateTextCount = 0
    var invalidateUpdatedTextCount = 0
    override public func invalidateText() {
        invalidateTextCount += 1
//        guard !hasCmdManager || !cmdManager.isRunningCommand else {
//            if !invalidateTextDispatched {
//                invalidateTextDispatched = true
//                DispatchQueue.main.async { [weak self] in
//                    guard let self = self else { return }
//                    self.invalidateTextDispatched = false
//                    self.invalidateText()
//                }
//            }
//            return
//        }
//
        invalidateTextDispatched = false
        invalidateText(forced: false)
    }

    private func invalidateText(forced: Bool = false) {
        if parent == nil {
            _attributedString = nil
            return
        }
        let newPadding = textPadding(elementKind: elementKind)
        if updateAttributedString() || forced || elementText.isEmpty || !NSEdgeInsetsEqual(textPadding, newPadding) {
            textPadding = newPadding
            updateTextFrame()
            invalidateRendering()
        }
    }

    private(set) var textPadding = NSEdgeInsetsZero

    func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        switch elementKind {
        case .check:
            return NSEdgeInsets(top: 0, left: 21, bottom: 0, right: 0)
        default:
            return NSEdgeInsetsZero
        }
    }

    override var bulletLayerPositionY: CGFloat {
        switch elementKind {
        case .heading(let level):
            return level == 1 ? firstLineBaseline - 15 : firstLineBaseline - 14
        default:
            return super.bulletLayerPositionY
        }
    }

    func buildTextFrames(position: CGPoint, width: CGFloat, height: CGFloat?, attributedString: NSAttributedString) -> (TextFrame, TextFrame?) {

        let textFrame = TextFrame.create(string: attributedString, atPosition: position, textWidth: width, singleLineHeightFactor: PreferencesManager.editorLineHeight, maxHeight: height)

        if debug {
            Logger.shared.logInfo("After updateTextFrame() - \(attributedString) / \(self.textFrame?.frame ?? .zero)")
        }

        var fakeFrame: TextFrame?
        if attributedString.string.isEmpty {
            let dummyText = buildAttributedString(for: BeamText(text: "Dummy!"), enableInteractions: false)
            fakeFrame = TextFrame.create(string: dummyText, atPosition: position, textWidth: width, singleLineHeightFactor: PreferencesManager.editorLineHeight, maxHeight: nil)

        }

        return (textFrame, fakeFrame)
    }

    var maxVisibleHeight: CGFloat? {
        return editor?.remainingIndicativeVisibleHeight
    }

    func updateTextFrame() {
        if selfVisible {
            invalidateUpdatedTextCount += 1
            if debug {
                Logger.shared.logInfo("updateTextFrame \(element.note?.title ?? "<untitled>")/\(elementId) - \(invalidateTextCount) - \(invalidateUpdatedTextCount) (width: \(availableWidth) - frame: \(frame)", category: .noteEditor)
            }
            emptyTextFrame = nil

            if debug {
                Logger.shared.logInfo("Before updateTextFrame() - \(attributedString) / \(self.textFrame?.frame ?? .zero)")
            }

            let width = contentsWidth - textPadding.left - textPadding.right

            let maxHeight = inInitialLayout ? maxVisibleHeight : nil
            let position = CGPoint(x: textPadding.left, y: textPadding.top)
            let (textFrame, fakeFrame) = buildTextFrames(position: position, width: width, height: maxHeight, attributedString: attributedString)

            self.textFrame = textFrame
            self.emptyTextFrame = fakeFrame

            if inInitialLayout, !textFrame.isComplete {
                // if we deliberately made the choice to compute a smaller height of text for performances reasons, we must start again with the full height when possible:
                DispatchQueue.userInteractive.async { [self, attributedString] in
                    let (textFrame, _) = self.buildTextFrames(position: position, width: width, height: nil, attributedString: attributedString)
                    DispatchQueue.main.async {
                        self.textFrame = textFrame
                        self.invalidateLayout()
                    }
                }
            }
        }
    }

    var textRect: NSRect {
        guard let tFrame = emptyTextFrame ?? textFrame else { return .zero }
        return tFrame.frame
    }

    override func deepInvalidateText() {
        invalidateText(forced: true)
        super.deepInvalidateText()
    }

    private func createMarkeeLayer(name: String, color: CGColor) -> ShapeLayer {
        let layer = ShapeLayer(name: name)
        layer.layer.actions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull()
        ]

        layer.layer.zPosition = -1
        layer.layer.position = CGPoint(x: contentsLead, y: 0)
        layer.shapeLayer.fillColor = color
        addLayer(layer)
        return layer
    }

    var _selectedTextLayer: ShapeLayer?
    var selectedTextLayer: ShapeLayer {
        if let layer = _selectedTextLayer {
            return layer
        }

        let layer = createMarkeeLayer(name: "selectedText", color: selectionColor)
        _selectedTextLayer = layer
        return layer
    }

    func updateSelection() {
        selectedTextLayer.layer.isHidden = true
        selectedTextLayer.shapeLayer.fillColor = selectionColor

        guard !readOnly else { return }

        //Draw Selection:
        if isEditing {
            if !selectedTextRange.isEmpty {
                selectedTextLayer.shapeLayer.path = buildMarkeeShape(selectedTextRange.lowerBound, selectedTextRange.upperBound)
            }
            selectedTextLayer.layer.isHidden = selectedTextRange.isEmpty
        }
    }

    public func isCursorInsideUneditableRange(caretIndex: Int) -> Bool {
        let caret = self.caretAtIndex(caretIndex)
        let sourceIndex = caret.indexInSource
        guard let uneditableRange = uneditableRangeAt(index: sourceIndex) else { return false }
        return sourceIndex > uneditableRange.lowerBound &&
            caret.edge != .trailing &&
            (sourceIndex < uneditableRange.upperBound || !caret.inSource)
    }

    public override func updateCursor() {
        guard let editor = self.editor else { return }
        let on = AppDelegate.main.isActive
            && editor.window?.isKeyWindow ?? false
            && !readOnly && editor.hasFocus && isFocused && editor.blinkPhase
            && (root?.state.nodeSelection?.nodes.isEmpty ?? true)
            && !isCursorInsideUneditableRange(caretIndex: caretIndex)

        let cursorRect = rectAt(caretIndex: caretIndex)

        cursorLayer.shapeLayer.fillColor = enabled ? cursorColor : disabledColor
        cursorLayer.layer.isHidden = !on
        cursorLayer.shapeLayer.path = CGPath(roundedRect: cursorRect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
    }

    var _decorationLayer: Layer?
    var decorationLayer: Layer {
        if let layer = _decorationLayer {
            return layer
        }

        let decoLayer = TextLinesDecorationLayer()
        decoLayer.zPosition = -1
        decoLayer.offset = contentsLead
        let layer = Layer(name: "lineDecoration", layer: decoLayer)
        _decorationLayer = layer
        addLayer(layer)
        return layer
    }

    public func updateDecorations() {
        guard let decoLayer =  decorationLayer.layer as? TextLinesDecorationLayer else { return }
        decoLayer.textLines = textFrame?.lines
    }

    override func updateRendering() -> CGFloat {
        var size = CGSize.zero
        if selfVisible {
            size = textRect.size

            switch elementKind {
            case .heading(1):
                size.height -= PreferencesManager.editorHeaderOneSize
            case .heading(2):
                size.height -= PreferencesManager.editorHeaderTwoSize
            default:
                size.height -= 5
            }
        }

        return size.height
    }

    override func updateColors() {
        super.updateColors()

        if !inInitialLayout {
            deepInvalidateText()
        }

        selectedTextLayer.shapeLayer.fillColor = selectionColor
        cursorLayer.shapeLayer.fillColor = cursorColor
    }

    var useActionLayer = false
    func createActionLayerIfNeeded() -> Layer? {
        guard element as? ProxyElement == nil, element.kind != .dailySummary, useActionLayer else { return nil }
        if let actionLayer = layers[Self.cmdEnterLayer] {
            return actionLayer
        }

        let actionLayer = ShortcutLayer(name: Self.cmdEnterLayer, text: "Search", icons: ["shortcut-cmd+return"]) { [unowned self] _ in
            self.editor?.startQuery(self, true)
        }
        performLayerChanges {
            actionLayer.layer.isHidden = true
        }
        addLayer(actionLayer, origin: CGPoint(x: availableWidth + childInset + actionLayerPadding, y: firstLineBaseline), global: false)
        return actionLayer
    }

    func updateActionLayer(animate: Bool) {
        guard let actionLayer = createActionLayerIfNeeded() else { return }
        let actionLayerYPosition = isHeader ? (contentsFrame.height / 2) - actionLayer.frame.height : 0

        if animate {
            performLayerChanges {
                actionLayer.frame = CGRect(x: self.availableWidth + self.childInset + self.actionLayerPadding, y: actionLayerYPosition, width: actionLayer.frame.width, height: actionLayer.frame.height).rounded()
            }
        } else {
            performLayerChanges(true) {
                actionLayer.frame = CGRect(x: self.availableWidth + self.childInset + self.actionLayerPadding, y: actionLayerYPosition, width: actionLayer.frame.width, height: actionLayer.frame.height).rounded()
            }
        }
    }

    func createCustomActionLayer(named: String, icons: [String] = [], text: String, at: CGPoint, action: @escaping () -> Void = {}) -> Layer {
        let layer = ShortcutLayer(name: named, text: text, icons: icons) { _ in
            action()
        }
        addLayer(layer, origin: at, global: false)
        return layer
    }

    // MARK: - Methods TextNode

    func screenIndex(for index: Int) -> Int? {
        return caretForSourcePosition(index)?.positionOnScreen
    }

    func screenRange(for range: Range<Int>) -> NSRange? {
        if let lowerIndex = screenIndex(for: range.lowerBound),
           let upperIndex = screenIndex(for: range.upperBound) {
            return NSRange(location: lowerIndex, length: upperIndex-lowerIndex)
        }
        return nil
    }

    func beginningOfLineFromPosition(_ position: Int) -> Int {
        guard let textFrame = textFrame,
              textFrame.lines.count > 1 else { return 0 }
        if let l = lineAt(index: position) {
            return textFrame.lines[l].range.lowerBound
        }
        return 0
    }

    func endOfLineFromPosition(_ position: Int) -> Int {
        guard let textFrame = textFrame,
              !textFrame.lines.isEmpty,
              textFrame.lines.count != 1 else { return textCount }

        if let l = lineAt(index: position) {
            let off = l < textFrame.lines.count - 1 ? -1 : 0
            return textFrame.lines[l].range.upperBound + off
        }
        return text.count
    }

    func currentSelectionWithFullSentences() -> String {
        let correctRange = cursorPosition == text.text.count ?
            selectedTextRange.lowerBound - 1..<selectedTextRange.upperBound - 1 :
            selectedTextRange.lowerBound + 1..<selectedTextRange.upperBound + 1

        let selectionStringRange = text.text.range(from: correctRange)
        return text.text.sentences(around: selectionStringRange)
    }

    override func onFocus() {
        guard let editor = self.editor else { return }
        super.onFocus()
        if editor.hasFocus {
            updateActionLayerVisibility(hidden: text.isEmpty)
        }
    }

    override func onUnfocus() {
        super.onUnfocus()
        updateActionLayerVisibility(hidden: true)
    }

    func updateActionLayerVisibility(hidden: Bool) {
        guard let actionLayer = createActionLayerIfNeeded() else { return }
        performLayerChanges {
            actionLayer.layer.isHidden = hidden
        }
    }

    private func isHoveringText() -> Bool {
        guard let editor = self.editor else { return false }
        let isMouseInsideFormatter = editor.inlineFormatter?.isMouseInsideView == true
        return hover && !isMouseInsideFormatter
    }

    // MARK: - Mouse Events
    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        guard let editor = self.editor else { return false }
        guard !mouseInfo.rightMouse else {
            return handleRightMouseDown(mouseInfo: mouseInfo)
        }

        if contentsFrame.containsY(mouseInfo.position) {

            mouseDownLocation = mouseInfo.position

            let clickPos = positionAt(point: mouseInfo.position)

            if mouseInfo.event.clickCount == 1 && editor.inlineFormatter != nil {
                focus(position: clickPos)
                root?.cancelSelection(.current)
                dragMode = .select(cursorPosition)

                debounceClickTimer = Timer.scheduledTimer(withTimeInterval: debounceClickInterval, repeats: false, block: { [weak self] (_) in
                    guard let self = self else { return }
                    self.editor?.hideInlineFormatter()
                })
                return true
            } else if mouseInfo.event.clickCount == 1 && mouseInfo.event.modifierFlags.contains(.shift) {
                guard allowSelection else { return true }
                dragMode = .select(cursorPosition)
                root?.extendSelection(to: clickPos)
                editor.showInlineFormatterOnKeyEventsAndClick()
                return true
            } else if mouseInfo.event.clickCount == 1 {
                guard allowSelection else { return true }
                focus(position: clickPos)
                root?.cancelSelection(.current)
                dragMode = .select(cursorPosition)
                return true
            } else if mouseInfo.event.clickCount == 2 {
                debounceClickTimer?.invalidate()
                guard allowSelection else { return true }
                root?.wordSelection(from: clickPos)
                if !selectedTextRange.isEmpty {
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
                return true
            } else {
                debounceClickTimer?.invalidate()
                guard allowSelection else { return true }
                root?.selectAll()
                editor.detectTextFormatterType()

                if root?.state.nodeSelection != nil {
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
                return true
            }
        }
        return false
    }

    private func handleRightMouseDown(mouseInfo: MouseInfo) -> Bool {
        guard let editor = self.editor else { return false }

        if contentsFrame.contains(mouseInfo.position) {
            let clickPos = positionAt(point: mouseInfo.position)
            // default right click behavior: select word

            let (linkRange, _) = linkRangeAt(point: mouseInfo.position)
            let internalLink = internalLink(at: mouseInfo.position)
            let internalLinkFrame = internalLinkRangeAndFrame(at: mouseInfo.position).1
            if let linkRange = linkRange {
                // open link right menu
                focus(position: linkRange.end)
                let selectRange = linkRange.position..<linkRange.end
                root?.selectedTextRange = selectRange
                cursor = .arrow
                editor.showLinkFormatterForSelection(mousePosition: mouseInfo.position, showMenu: true)
            } else if let internalLink = internalLink, let linkFrame = internalLinkFrame {
                focus(position: clickPos)
                let menuPosition = CGPoint(x: mouseInfo.position.x + self.offsetInDocument.x - 10, y: linkFrame.maxY + self.offsetInDocument.y + 7)
                editor.showInternalLinkContextMenu(at: menuPosition, for: internalLink)
            } else {
                guard allowSelection else { return true }
                focus(position: clickPos)
                root?.wordSelection(from: clickPos)
                if !selectedTextRange.isEmpty {
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
            }
            return true
        }
        return false
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        guard let editor = self.editor else { return false }
        editor.detectTextFormatterType()

        if mouseIsDragged, allowSelection {
            editor.showInlineFormatterOnKeyEventsAndClick(isKeyEvent: false)
        }

        if !mouseIsDragged, contentsFrame.containsY(mouseInfo.position) {
            if let link = linkAt(point: mouseInfo.position) {
                let inBackground = mouseInfo.event.modifierFlags.contains(.command)
                openExternalLink(link: link, element: element, inBackground: inBackground)
                return true
            }

            if let link = internalLink(at: mouseInfo.position) {
                editor.openCard(link, nil, nil)
                return true
            }
        }

        mouseIsDragged = false
        return false
    }

    private func handleMouseHoverState(mouseInfo: MouseInfo) {
        guard let editor = self.editor else { return }
        let isMouseInContentFrame = contentsFrame.contains(mouseInfo.position)
        let isMouseInsideFormatter = editor.inlineFormatter?.isMouseInsideView == true
        let mouseHasChangedTextPosition = lastHoverMouseInfo?.position != mouseInfo.position
        if mouseHasChangedTextPosition && isMouseInContentFrame {
            let link = linkAt(point: mouseInfo.position)
            let (internalLink, _) = internalLinkRangeAndFrame(at: mouseInfo.position)

            if link != nil {
                let (linkRange, linkFrame) = linkRangeAt(point: mouseInfo.position)
                if let linkRange = linkRange, let currentNode = widgetAt(point: mouseInfo.position) as? TextNode, !isMouseInsideFormatter {
                    invalidateTextAsync()
                    cursor = .pointingHand
                    if let positionInText = indexAt(point: mouseInfo.position, limitToTextString: false),
                       BeamText.isPositionOnLinkArrow(positionInText, in: linkRange) {
                        editor.linkStartedHoveringArrow(
                            for: currentNode,
                            targetRange: linkRange.position ..< linkRange.end,
                            frame: linkFrame,
                            url: link,
                            linkTitle: linkRange.string
                        )
                    }
                }
            } else {
                if !isMouseInsideFormatter {
                    cursor = internalLink != nil ? .pointingHand : .iBeam
                }
                editor.linkStoppedHovering()
                invalidateTextAsync()
            }
        }
        lastHoverMouseInfo = mouseInfo
        if isMouseInsideFormatter {
            cursor = nil
        }
    }

    override func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        _ = super.mouseMoved(mouseInfo: mouseInfo)
        self.handleMouseHoverState(mouseInfo: mouseInfo)
        return false
    }

    override func mouseDragged(mouseInfo: MouseInfo) -> Bool {
        guard let editor = self.editor, isFocused else { return false }

        // Prevent accidental drag for very small movements.
        guard abs(mouseInfo.position.x - mouseDownLocation.x) >= 1.0 ||
              abs(mouseInfo.position.y - mouseDownLocation.y) >= 1.0 else {
            return false
        }

        let p = positionAt(point: mouseInfo.position)
        root?.cursorPosition = p

        switch dragMode {
        case .none:
            return false
        case .select(let o):
            root?.selectedTextRange = text.clamp(p < o ? p..<o : o..<p)
            mouseIsDragged = root?.state.nodeSelection == nil

            // When more than one bullet is selected hide & disable cmd+enter action
            if let nodeSelection = root?.state.nodeSelection, nodeSelection.nodes.count > 1 {
                updateActionLayerVisibility(hidden: true)
            } else {
                updateActionLayerVisibility(hidden: false)
            }

            // Update inline formatter on drag
            if root?.state.nodeSelection == nil { editor.updateInlineFormatterOnDrag(isDragged: true) }
        }
        invalidate()

        return true
    }

    // MARK: - Text & Cursor Position

    public func lineAt(point: NSPoint) -> Int {
        guard let textFrame = textFrame, !textFrame.lines.isEmpty else { return 0 }
        let point = CGPoint(x: point.x, y: point.y - textPadding.top)
        let y = point.y
        if y >= contentsFrame.height {
            let v = textFrame.lines.count - 1
            return max(v, 0)
        } else if y < 0 {
            return 0
        }

        for (i, l) in textFrame.lines.enumerated() where point.y < l.frame.minY + CGFloat(fontSize) {
            return i
        }

        return max(0, min(Int(y / CGFloat(fontSize)), textFrame.lines.count - 1))
    }

    public func lineAt(index: Int) -> Int? {
        guard index >= 0 else { return nil }
        guard let textFrame = textFrame else { return 0 }
        guard !textFrame.lines.isEmpty else { return 0 }
        for (i, l) in textFrame.lines.enumerated() where index < l.range.lowerBound {
            return i - 1
        }
        if !textFrame.lines.isEmpty {
            return textFrame.lines.count - 1
        }
        return nil
    }

    public func position(at index: String.Index) -> Int {
        return text.position(at: index)
    }

    public override func position(after index: Int, avoidUneditableRange: Bool = false) -> Int {
        guard let textFrame = textFrame else { return 0 }
        var newIndex = textFrame.position(after: index)
        if avoidUneditableRange,
           let movedIndex = caretIndexAvoidingUneditableRange(newIndex, after: true) {
            newIndex = movedIndex
        }
        return newIndex
    }

    public override func position(before index: Int, avoidUneditableRange: Bool = false) -> Int {
        guard let textFrame = textFrame else { return 0 }
        var newIndex = textFrame.position(before: index)
        if avoidUneditableRange,
           let movedIndex = caretIndexAvoidingUneditableRange(newIndex, after: false) {
            newIndex = movedIndex
        }
        return newIndex
    }

    public func positionAt(point: NSPoint) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard !textFrame.lines.isEmpty else { return 0 }
        let lineIndex = lineAt(point: point)
        let lines = textFrame.lines
        let line = lines[lineIndex]
        return line.stringIndexFor(position: NSPoint(x: point.x - contentsPadding.left, y: point.y - contentsPadding.top))
    }

    override public func caretIndexAvoidingUneditableRange(_ caretIndex: Int, after: Bool) -> Int? {
        let caret = self.caretAtIndex(caretIndex)
        let sourceIndex = caret.indexInSource
        guard let sourceRange = uneditableRangeAt(index: sourceIndex) else { return nil }
        guard sourceIndex != sourceRange.endIndex || caret.inSource == false else {
            return nil
        }

        if after {
            guard let newIndex = caretIndexForSourcePosition(sourceRange.upperBound) else { return nil }
            return nextInSourceCaretIndex(at: newIndex)
        } else {
            return caretIndexForSourcePosition(sourceRange.lowerBound)
        }
    }

    private func nextInSourceCaretIndex(at caretIndex: Int) -> Int {
        let caret = caretAtIndex(caretIndex)
        guard !caret.inSource else { return caretIndex }
        return position(after: caretIndex)
    }

    public func indexAt(point: NSPoint, limitToTextString: Bool = true) -> Int? {
        guard let textFrame = textFrame else { return nil }
        guard !textFrame.lines.isEmpty else { return nil }
        let line = lineAt(point: point)
        guard line >= 0 else { return nil }
        let l = textFrame.lines[line]
        let point = NSPoint(x: point.x - contentsPadding.left, y: point.y - contentsPadding.top)
        var lineFrame = l.frame
        if line > 0 && line < textFrame.lines.count { // add padding for inbetween lines
            lineFrame = lineFrame.insetBy(dx: 0, dy: -fontSize)
            if line == textFrame.lines.count - 1 { // add only top padding for last line
                lineFrame.size.height -= fontSize
            }
        }
        guard lineFrame.contains(point)  else { return nil } // point is outside the line

        let displayIndex = l.stringIndexFor(position: point)
        if !limitToTextString {
            // can be outside of text string for decoration element like link arrow
            return displayIndex
        }
        return min(displayIndex, text.count - 1)
    }

    public func offsetAt(caretIndex: Int) -> CGFloat {
        guard let textFrame = emptyTextFrame ?? self.textFrame else { return textPadding.left }
        guard !textFrame.lines.isEmpty else { return 0 }
        let caret = textFrame.carets[caretIndex]
        return caret.offset.x + textPadding.left
    }

    override public func offsetAt(index: Int) -> CGFloat {
        guard let textFrame = emptyTextFrame ?? self.textFrame else { return textPadding.left }
        guard !textFrame.lines.isEmpty else { return textPadding.left }
        guard let line = lineAt(index: index) else { return textPadding.left }
        let textLine = textFrame.lines[line]
        let result = textLine.offsetFor(index: index)
        return CGFloat(result)
    }

    public func offsetAndFrameAt(index: Int) -> (CGFloat, NSRect) {
        guard let textFrame = textFrame else { return (offsetAt(index: index), .zero) }

        guard !textFrame.lines.isEmpty,
              let line = lineAt(index: index) else { return (offsetAt(index: index), .zero) }

        let textLine = textFrame.lines[line]
        let result = textLine.offsetFor(index: index)

        return (CGFloat(result), textLine.frame)
    }

    public func offsetAndFrameAt(caretIndex: Int) -> (CGFloat, NSRect) {
        guard let textFrame = textFrame else { return (offsetAt(caretIndex: caretIndex), .zero) }
        let caret = textFrame.carets[caretIndex]

        guard !textFrame.lines.isEmpty,
              let line = lineAt(index: caret.indexInSource) else { return (offsetAt(caretIndex: caretIndex), .zero) }

        let textLine = textFrame.lines[line]

        return (caret.offset.x, textLine.frame)
    }

    override public func caretAbove(_ caretIndex: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        let currentCaret = textFrame.carets[caretIndex]
        let lineAboveIndex = currentCaret.line - 1
        guard lineAboveIndex >= 0 else { return 0 }
        let offset = currentCaret.offset
        let lineAbove = textFrame.lines[lineAboveIndex]
        if let index = lineAbove.carets.binarySearch(predicate: {
            $0.offset.x < offset.x
        }) {
            return lineAbove.caretOffset + index
        }

        return lineAbove.caretOffset + lineAbove.carets.count - 1
    }

    override public func caretBelow(_ caretIndex: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        let currentCaret = textFrame.carets[caretIndex]
        let lineBelowIndex = currentCaret.line + 1
        guard lineBelowIndex < textFrame.lines.count else { return textFrame.carets.count - 1 }
        let offset = currentCaret.offset
        let lineBelow = textFrame.lines[lineBelowIndex]
        if let index = lineBelow.carets.binarySearch(predicate: {
            $0.offset.x < offset.x
        }) {
            return lineBelow.caretOffset + index
        }

        return lineBelow.caretOffset + lineBelow.carets.count - 1
    }

    override public func positionForCaretIndex(_ caretIndex: Int) -> Int {
        return textFrame?.carets[caretIndex].positionInSource ?? 0
    }
    override public func isOnFirstLine(_ position: Int) -> Bool {
        guard let l = lineAt(index: position) else { return false }
        return l == 0
    }

    override public func isOnLastLine(_ position: Int) -> Bool {
        guard let textFrame = textFrame else { return true }
        guard textFrame.lines.count > 1 else { return true }
        guard let l = lineAt(index: position) else { return false }
        return l == textFrame.lines.count - 1
    }

    public func rectAt(sourcePosition: Int) -> NSRect {
        computeRendering()
        let textLine: TextLine? = {
            if let emptyLayout = emptyTextFrame {
                return emptyLayout.lines[0]
            }

            guard let cursorLine = lineAt(index: sourcePosition <= 0 ? 0 : sourcePosition) else { fatalError() }
            return textFrame?.lines[cursorLine] ?? nil
        }()

        guard let line = textLine else { return NSRect.zero }
        let pos = sourcePosition
        let x1 = offsetAt(index: pos)
        let cursorRect = NSRect(x: x1, y: line.frame.minY, width: sourcePosition == text.count ? bigCursorWidth : smallCursorWidth, height: line.bounds.height)

        return cursorRect
    }

    override public func rectAt(caretIndex: Int) -> NSRect {
        computeRendering()
        guard let textFrame = emptyTextFrame ?? textFrame else { return .zero }
        let caret = caretIndex >= textFrame.carets.count ? initialCaret : textFrame.carets[caretIndex]
        let position = caret.positionInSource

        guard caret.line < textFrame.lines.count else {
            return .null
        }

        let textLine: TextLine = {
            if let emptyLayout = emptyTextFrame {
                return emptyLayout.lines[0]
            }

            return textFrame.lines[caret.line]
        }()

        let x1 = caret.offset.x
        let cursorRect = NSRect(x: x1, y: textLine.frame.minY, width: position == text.count ? bigCursorWidth : smallCursorWidth, height: textLine.bounds.height)

        return cursorRect
    }

    override public func indexOnLastLine(atOffset x: CGFloat) -> Int {
        guard let lines = (emptyTextFrame ?? self.textFrame)?.lines else { return 0 }
        guard !lines.isEmpty else { return 0 }
        guard let line = lines.last else { return 0 }
        let index = line.stringIndexFor(position: NSPoint(x: x - contentsPadding.left, y: 0))
        if index == line.range.upperBound {
            return endOfLineFromPosition(index)
        }
        return index
    }

    override public func indexOnFirstLine(atOffset x: CGFloat) -> Int {
        guard let lines = (emptyTextFrame ?? self.textFrame)?.lines else { return 0 }
        guard !lines.isEmpty else { return 0 }
        guard let line = lines.first else { return 0 }
        let index = line.stringIndexFor(position: NSPoint(x: x - contentsPadding.left, y: 0))
        if index == line.range.upperBound {
            return endOfLineFromPosition(index)
        }
        return index
    }

    // MARK: - Links Ranges
    public func linkAt(point: NSPoint) -> URL? {
        guard let pos = indexAt(point: point) else { return nil }
        return linkAt(index: pos)
    }

    public func linkAt(index: Int) -> URL? {
        let range = elementText.rangeAt(position: index)
        guard let linkAttribIndex = range.attributes.firstIndex(where: { attrib -> Bool in
            attrib.rawValue == BeamText.Attribute.link("").rawValue
        }) else { return nil }

        switch range.attributes[linkAttribIndex] {
        case .link(let link):
            return URL(string: link)
        default:
            return nil
        }
    }

    public func internalLink(at point: NSPoint) -> UUID? {
        guard let pos = indexAt(point: point) else { return nil }
        return internalLink(at: pos)
    }

    public func internalLink(at index: Int) -> UUID? {
        guard let range = internalLinkRange(at: index) else { return nil }
        for attr in range.attributes {
            switch attr {
            case .internalLink(let value):
                return value
            default:
                continue
            }
        }
        return nil
    }

    func linkRangeAt(point: NSPoint) -> (BeamText.Range?, NSRect?) {
        guard let textFrame = textFrame else { return (nil, nil) }
        guard !textFrame.lines.isEmpty else { return (nil, nil) }
        let line = lineAt(point: point)
        guard line >= 0 else { return (nil, nil) }
        let l = textFrame.lines[line]
        guard let pos = indexAt(point: point) else { return (nil, nil) }
        guard let range = linkRangeAt(index: pos) else { return (nil, nil) }

        let start = range.position
        let end = range.end
        let startOffset = offsetAt(index: start)
        let endOffset = offsetAt(index: end)

        let linkFrame = NSRect(x: startOffset, y: l.frame.minY, width: endOffset - startOffset, height: l.frame.height).offsetBy(dx: contentsPadding.left, dy: contentsPadding.top)
        return (range, linkFrame)
    }

    func linkRangeAt(index: Int) -> BeamText.Range? {
        let range = elementText.rangeAt(position: index)
        let hasLink = range.attributes.contains { attrib -> Bool in
            attrib.rawValue == BeamText.Attribute.link("").rawValue
        }
        return hasLink ? range : nil
    }

    public func internalLinkRangeAndFrame(at point: CGPoint) -> (BeamText.Range?, CGRect?) {
        guard let textFrame = textFrame else { return (nil, nil) }
        let line = lineAt(point: point)
        guard line >= 0, !textFrame.lines.isEmpty else { return (nil, nil) }
        let l = textFrame.lines[line]
        let point = NSPoint(x: point.x - contentsPadding.left, y: point.y - contentsPadding.top)
        guard l.frame.minX <= point.x && l.frame.maxX >= point.x else { return (nil, nil) } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: point)
        let pos = min(displayIndex, attributedString.length - 1)
        guard let range = internalLinkRange(at: pos) else { return (nil, nil) }

        let start = range.position
        let end = range.end
        let startOffset = offsetAt(index: start)
        let endOffset = offsetAt(index: end)

        let linkFrame = NSRect(x: startOffset, y: l.frame.minY, width: endOffset - startOffset, height: l.frame.height).offsetBy(dx: contentsPadding.left, dy: contentsPadding.top)

        return (range, linkFrame)
    }

    public func internalLinkRange(at index: Int) -> BeamText.Range? {
        let range = elementText.rangeAt(position: index)
        let hasInternalLink = range.attributes.contains { $0.isInternalLink }
        return hasInternalLink ? range : nil
    }

    public func uneditableRangeAt(index: Int) -> Range<Int>? {
        let range = elementText.rangeAt(position: index)
        let isNotEditable = range.attributes.first { $0.isEditable == false }
        guard isNotEditable != nil else { return nil }
        return range.position..<range.end
    }

    // MARK: - Print

    override public func printTree(level: Int = 0) -> String {
        return String.tabs(level)
            + (children.isEmpty ? "- " : (open ? "v - " : "> - "))
            + text.text + "\n"
            + (open ?
                children.reduce("", { result, child -> String in
                    result + child.printTree(level: level + 1)
                })
                : "")
    }

    // MARK: - Private Methods

    // update the internal attributed string and return true if it was changed
    @discardableResult private func updateAttributedString() -> Bool {
        let str = buildAttributedString()
        if _attributedString?.isEqual(to: str) ?? false {
            return false
        }

        _attributedString = str
        return true
    }

    override internal func drawDebug(in context: CGContext) {
        // draw debug:
        guard debug, hover || isEditing else { return }

        let c = isEditing ? NSColor.red.cgColor : NSColor.gray.cgColor
        context.setStrokeColor(c)
        let bounds = NSRect(origin: CGPoint(), size: currentFrameInDocument.size)
        context.stroke(bounds)

        context.setFillColor(c.copy(alpha: 0.2)!)
        context.fill(contentsFrame)
    }

    private func buildAttributedString(for beamText: BeamText, enableInteractions: Bool = true) -> NSMutableAttributedString {

        var mouseInteraction: MouseInteraction?
        if enableInteractions, let hoverMouse = lastHoverMouseInfo, isHoveringText() {
            if let pos = indexAt(point: hoverMouse.position, limitToTextString: false) {
                let nsrange = NSRange(location: pos, length: 1)
                mouseInteraction = MouseInteraction(type: MouseInteractionType.hovered, range: nsrange)
            }
        }
        let caret = enableInteractions ? (isFocused ? caretAtIndex(caretIndex) : nil) : nil
        let selectedRange = enableInteractions ? (selected ? text.wholeRange : selectedTextRange) : text.wholeRange
        let str = beamText.buildAttributedString(node: self,
                                                 caret: caret,
                                                 selectedRange: selectedRange,
                                                 mouseInteraction: mouseInteraction)
        let paragraphStyle = NSMutableParagraphStyle()
        //        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = interlineFactor
//        paragraphStyle.lineSpacing = 40
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.paragraphSpacing = 10

        str.addAttribute(.paragraphStyle, value: paragraphStyle, range: str.wholeRange)
        str.addAttribute(.kern, value: NSNumber(value: 0), range: str.wholeRange)
        str.addAttribute(.ligature, value: NSNumber(value: 1), range: str.wholeRange)
//        str.addAttribute(.tracking, value: NSNumber(value: 1), range: str.wholeRange)
        return str
    }

    private func buildAttributedString() -> NSAttributedString {
        if elementText.isEmpty && !isFocused && !(editor?.hasFocus ?? false) {
            return buildAttributedString(for: placeholder).addAttributes([NSAttributedString.Key.foregroundColor: BeamColor.Generic.placeholder.cgColor, NSAttributedString.Key.font: BeamFont.regular(size: PreferencesManager.editorFontSize).nsFont])
        }
        return buildAttributedString(for: elementText)
    }

    internal func actionLayerMousePosition(from mouseInfo: MouseInfo) -> NSPoint {
        return NSPoint(x: contentsLead + mouseInfo.position.x, y: mouseInfo.position.y)
    }

    override func dumpWidgetTree(_ level: Int = 0) -> [String] {
        let tabs = String.tabs(level)
        let str = "\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers - element id: \(element.id) [\(elementText.text)]\(layer.superlayer == nil ? " DETTACHED" : "") \(needLayout ? "NeedLayout":"")"
        var strs = [str]
        for c in children {
            strs.append(contentsOf: c.dumpWidgetTree(level + 1))
        }

        return strs
    }

    public override func accessibilityString(for range: NSRange) -> String? {
        let t = text
        return t.substring(range: max(0, range.lowerBound) ..< min(t.count, range.upperBound))
    }

    //    Returns the attributed substring for the specified range of characters.
    public override func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
        return attributedString.attributedSubstring(from: range)
    }

    //    Returns the Rich Text Format (RTF) data that describes the specified range of characters.
    public override func accessibilityRTF(for range: NSRange) -> Data? {
        return nil
    }

    //    Returns the rectangle enclosing the specified range of characters.
    public override func accessibilityFrame(for: NSRange) -> NSRect {
        return contentsFrame
    }

    //    Returns the line number for the line holding the specified character index.
    public override func accessibilityLine(for index: Int) -> Int {
        return lineAt(index: index) ?? 0
    }

    //    Returns the range of characters for the glyph that includes the specified character.
    public override func accessibilityRange(for index: Int) -> NSRange {
        return attributedString.wholeRange
    }

    //    Returns a range of characters that all have the same style as the specified character.
    public override func accessibilityStyleRange(for index: Int) -> NSRange {
        return attributedString.wholeRange
    }

    //    Returns the range of characters in the specified line.
    public override func accessibilityRange(forLine line: Int) -> NSRange {
        guard let textFrame = textFrame,
              line < textFrame.lines.count
        else { return NSRange() }
        let range = textFrame.lines[line].range
        return NSRange(location: range.lowerBound, length: range.count)
    }

    //    Returns the range of characters for the glyph at the specified point.
    public override func accessibilityRange(for point: NSPoint) -> NSRange {
        let lineIndex = lineAt(point: point)
        guard let line = textFrame?.lines[lineIndex] else { return NSRange() }

        let range = line.range
        return NSRange(location: range.lowerBound, length: range.count)
    }

    public override func accessibilityValue() -> Any? {
        return text.text
    }

    public override func setAccessibilityValue(_ accessibilityValue: Any?) {
        switch accessibilityValue {
        case is String:
            guard let value = accessibilityValue as? String else { return }
            text = BeamText(text: value)

        case is NSAttributedString:
            guard let value = accessibilityValue as? NSAttributedString else { return }
            text = BeamText(text: value.string)

        default:
            return
        }
    }

    public override func accessibilityVisibleCharacterRange() -> NSRange {
        return attributedString.wholeRange
    }

    public override func isAccessibilityEnabled() -> Bool {
        return true
    }

    public override func accessibilityNumberOfCharacters() -> Int {
        return text.count
    }

    public override func accessibilitySelectedText() -> String? {
        guard let t = root?.selectedText else { return nil }
        return t.isEmpty ? nil : t
    }

    public override func accessibilitySelectedTextRange() -> NSRange {
        guard let range = root?.state.selectedTextRange else { return NSRange() }
        return NSRange(location: range.lowerBound, length: range.count)
    }

    public override func accessibilitySelectedTextRanges() -> [NSValue]? {
        guard let range = root?.state.selectedTextRange else { return [] }
        return [NSValue(range: NSRange(location: range.lowerBound, length: range.count))]
    }

    /*
     I used this code to debug accessibility and try to understand what is expected of us.
     Thus far these are requested by the system:
     _accessibilityLabel
     accessibilityChildren
     accessibilityFrame
     accessibilityIdentifier
     accessibilityMaxValue
     accessibilityMinValue
     accessibilityNumberOfCharacters
     accessibilityParent
     accessibilityRole
     accessibilityRoleDescription
     accessibilitySubrole
     accessibilityTitle
     accessibilityTopLevelUIElement
     accessibilityValue
     accessibilityValueDescription
     accessibilityVisibleChildren
     accessibilityWindow
     isAccessibilityElement
     setAccessibilityChildren:
     setAccessibilityEnabled:
     setAccessibilityFrame:
     setAccessibilityLabel:
     setAccessibilityParent:
     setAccessibilityRole:
     setAccessibilityRoleDescription:
     setAccessibilityTitle:
     setAccessibilityTopLevelUIElement:
     setAccessibilityValue:
     setAccessibilityWindow:


    public override func isAccessibilitySelectorAllowed(_ selector: Selector) -> Bool {
        Logger.shared.logDebug("isAccessibilitySelectorAllowed(\(selector))")
        return true
    }
*/

    override func subscribeToElement(_ element: BeamElement) {
        elementScope.removeAll()

        element.$text
            .sink { [unowned self] newValue in
                elementText = newValue
                self.updateActionLayerVisibility(hidden: elementText.isEmpty || !isFocused)
                self.invalidateText()
            }.store(in: &elementScope)

        element.$kind
            .sink { [unowned self] newValue in
                elementKind = newValue
                self.invalidateText()
            }.store(in: &elementScope)

        open = element.open

        elementText = element.text
        elementKind = element.kind
    }

    public override func caretAtIndex(_ index: Int) -> Caret {
        guard let textFrame = textFrame else {
            return initialCaret
        }

        guard index < textFrame.carets.count else {
            return textFrame.carets.last ?? initialCaret
        }
        return textFrame.carets[index]
    }

    func caretForSourcePosition(_ index: Int) -> Caret? {
        return textFrame?.caretForSourcePosition(index)
    }

    override public func caretIndexForSourcePosition(_ index: Int) -> Int? {
        return textFrame?.caretIndexForSourcePosition(index)
    }

    var initialCaret: Caret {
        Caret(offset: NSPoint(x: textPadding.left, y: textPadding.top), indexInSource: 0, indexOnScreen: 0, edge: .leading, inSource: true, line: 0)
    }

    override public var textCount: Int {
        displayedElement.text.count
    }

    public func textFramesAt(range: Range<Int>) -> [NSRect] {
        var rects = [NSRect]()
        let start = range.lowerBound
        let end = range.upperBound
        let startLine = lineAt(index: start)!
        let endLine = lineAt(index: end)!
        let line1 = textFrame!.lines[startLine]
        let line2 = textFrame!.lines[endLine]
        let xStart = offsetAt(index: start)
        let xEnd = offsetAt(index: end)

        if startLine == endLine {
            // Selection begins and ends on the same line:
            let markRect = NSRect(x: xStart, y: line1.frame.minY, width: xEnd - xStart, height: line1.bounds.height)
            rects.append(markRect)
        } else {
            let markRect1 = NSRect(x: xStart, y: line1.frame.minY, width: frame.width - xStart, height: line2.frame.minY - line1.frame.minY )
            rects.append(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: 0, y: line1.frame.maxY, width: frame.width, height: line2.frame.minY - line1.frame.maxY)
                rects.append(markRect2)
            }

            let markRect3 = NSRect(x: 0, y: line1.frame.maxY, width: xEnd, height: CGFloat(line2.frame.maxY - line1.frame.maxY) + 1)
            rects.append(markRect3)
        }

        return rects
    }

    class AccessibleTextElement: NSAccessibilityElement {
        var children: [AccessibleTextElement]
        public override func accessibilityChildren() -> [Any]? {
            return children.isEmpty ? nil : children
        }

        init(identifier: String, text: String, frame: NSRect, children: [AccessibleTextElement]) {
            self.children = children
            super.init()
            setAccessibilityRole(.button)
            setAccessibilityElement(true)
            setAccessibilityEnabled(true)
            setAccessibilityValue(text)
            setAccessibilityLabel(text)
            setAccessibilityTitle(text)
            setAccessibilityIdentifier(identifier)
            setAccessibilityFrameInParentSpace(frame)
            setAccessibilityActivationPoint(NSPoint(x: frame.width/2, y: frame.height/2))
            setAccessibilityHidden(false)
            for child in children {
                child.setAccessibilityParent(self)
            }
        }
    }
    var sentences: [AccessibleTextElement] = []

    public override func accessibilityChildren() -> [Any]? {
        sentences = []
        let text = self.text.text
        let mainFrame = accessibilityFrameInParentSpace()

        var words = [AccessibleTextElement]()

        for sentence in text.sentenceRanges {
            let sentenceString = String(text[sentence])
            let sentenceRange = text.range(from: sentence)
            let frames = textFramesAt(range: sentenceRange)
            var sentenceFrame = frames.first ?? NSRect()

            sentenceFrame.origin.y = mainFrame.height - sentenceFrame.maxY

            // Now fish for words:
            for word in sentenceString.wordRanges {
                let wordString = String(sentenceString[word])
                let wordRange = sentenceString.range(from: word)
                let frames = textFramesAt(range: (sentenceRange.lowerBound + wordRange.lowerBound) ..< (sentenceRange.lowerBound + wordRange.upperBound))
                var wordFrame = frames.first ?? NSRect()
                let actualY = contentsFrame.height - wordFrame.maxY
                wordFrame.origin.y = actualY
//                wordFrame.origin.y = sentenceFrame.height - wordFrame.maxY
                let wordElement = AccessibleTextElement(identifier: "word", text: wordString, frame: wordFrame, children: [])
                words.append(wordElement)
            }

//            let sentenceElement = AccessibleTextElement(identifier: "sentence", text: sentenceString, frame: sentenceFrame, children: words)
//            sentenceElement.setAccessibilityParent(self)
            sentences += words
        }

        for link in self.text.linkRanges {
            let linkString = link.string
            let linkRange = link.position ..< link.position + link.end

            let frames = textFramesAt(range: linkRange)
            var linkFrame = frames.first ?? NSRect()
            let actualY = contentsFrame.height - linkFrame.maxY
            linkFrame.origin.y = actualY
            let linkElement = AccessibleTextElement(identifier: "link", text: linkString, frame: linkFrame, children: [])
            sentences.append(linkElement)
        }

        for link in self.text.internalLinkRanges {
            let linkString = link.string
            let linkRange = link.position ..< link.position + link.end

            let frames = textFramesAt(range: linkRange)
            var linkFrame = frames.first ?? NSRect()
            let actualY = contentsFrame.height - linkFrame.maxY
            linkFrame.origin.y = actualY
            let linkElement = AccessibleTextElement(identifier: "internalLink", text: linkString, frame: linkFrame, children: [])
            sentences.append(linkElement)
        }

        return sentences + (super.accessibilityChildren() ?? []).map({ elem in
            if let e = elem as? NSAccessibilityElement {
                e.setAccessibilityParent(self)
            }
            return elem

        })
    }

    public override func clampTextRange(_ range: Range<Int>) -> Range<Int> {
        text.clamp(range)
    }
}
