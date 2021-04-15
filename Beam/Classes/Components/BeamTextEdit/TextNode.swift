//
//  TextNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 07/10/2020.
//
// swiftlint:disable file_length

import Foundation
import AppKit
import NaturalLanguage
import Combine
import BeamCore

// swiftlint:disable:next type_body_length
public class TextNode: Widget {
    var element: BeamElement { didSet {
        subscribeToElement(element)
    }}

    var elementId: UUID {
        unproxyElement.id
    }

    var elementNoteTitle: String? {
        unproxyElement.note?.title
    }

    var unproxyElement: BeamElement {
        guard let elem = element as? ProxyElement else { return element }
        return elem.proxy
    }

    var elementScope = Set<AnyCancellable>()
    var elementText = BeamText()
    var elementKind = ElementKind.bullet

    var textFrame: TextFrame?
    var emptyTextFrame: TextFrame?

    var mouseIsDragged = false
    var lastHoverMouseInfo: MouseInfo?
    var interlineFactor = CGFloat(1.3)
    var interNodeSpacing = CGFloat(0)
    var indent: CGFloat { selfVisible ? 18 : 0 }
    var fontSize: CGFloat = 15

    override var contentsScale: CGFloat {
        didSet {
            guard let actionLayer = layers["CmdEnterLayer"] as? ShortcutLayer else { return }
            actionLayer.set(contentsScale)
        }
    }

    override var hover: Bool {
        didSet {
            if oldValue != hover {
                invalidateText()
            }
        }
    }

    var text: BeamText {
        get { element.text }
        set {
            guard element.text != newValue else { return }

            if newValue.isEmpty { updateActionLayerVisibility(hidden: true) }

            element.text = newValue
            element.note?.modifiedByUser()
            invalidateText()
        }
    }

    override var open: Bool {
        didSet {
            guard !initialLayout, element.open != open else { return }
            element.open = open
        }
    }

    var placeholder = BeamText() {
        didSet {
            guard oldValue != text else { return }
            invalidateText()
        }
    }

    var strippedText: String {
        text.text
    }

    var fullStrippedText: String {
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

    var config: TextConfig {
        root?.config ?? TextConfig()
    }

    var color: NSColor { config.color }
    var disabledColor: NSColor { config.disabledColor }
    var selectionColor: NSColor { config.selectionColor }
    var markedColor: NSColor { config.markedColor }
    var alpha: Float { config.alpha }
    var blendMode: CGBlendMode { config.blendMode }

    var selectedTextRange: Range<Int> { root?.selectedTextRange ?? 0..<0 }
    var markedTextRange: Range<Int>? { root?.markedTextRange }
    var cursorsStartPosition: Int { root?.cursorPosition ?? 0 }
    var cursorPosition: Int { root?.cursorPosition ?? 0 }

    var showDisclosureButton: Bool {
        !children.isEmpty
    }

    var showIdentationLine: Bool {
        return depth == 1
    }

    var readOnly: Bool = false
    var isEditing: Bool {
        guard let r = root else { return false }
        return r.focusedWidget === self && r.state.nodeSelection == nil
    }

    var firstLineHeight: CGFloat {
        let textFrame = emptyTextFrame ?? self.textFrame
        return textFrame?.lines.first?.bounds.height ?? CGFloat(fontSize * interlineFactor)
    }
    var firstLineBaseline: CGFloat {
        let textFrame = emptyTextFrame ?? self.textFrame
        if let firstLine = textFrame?.lines.first {
            let h = firstLine.typographicBounds.ascent
            return CGFloat(h) + firstLine.frame.minY
        }
        let f = BeamText.font(fontSize)
        return f.ascender
    }

    let smallCursorWidth = CGFloat(2)
    let bigCursorWidth = CGFloat(7)
    var maxCursorWidth: CGFloat { max(smallCursorWidth, bigCursorWidth) }

    // walking the node tree:
    var inOpenBranch: Bool {
        guard let p = parent as? TextNode else { return true }
        return p.open && p.inOpenBranch
    }

    var isHeader: Bool {
        switch elementKind {
        case .heading:
            return true
        default:
            return false
        }
    }

    private var debounceClickTimer: Timer?
    private var actionLayerIsHovered = false
    private var icon = NSImage(named: "editor-cmdreturn")

    private let debounceClickInterval = 0.23
//    public static var actionLayerWidth = CGFloat(80)
//    public static var actionLayerXOffset = CGFloat(30)
//    private var actionLayerFrame: CGRect { CGRect(x: Self.actionLayerXOffset, y: 0, width: Self.actionLayerWidth, height: 20) }
    private var bulletLayerPositionX = CGFloat(14)
    private var actionLayerPadding = CGFloat(3.5)

    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    func buildTextChildren(elements: [BeamElement]) -> [Widget] {
        elements.map { childElement -> TextNode in
            nodeFor(childElement, withParent: self)
        }
    }

    func updateTextChildren(elements: [BeamElement]) {
        children = buildTextChildren(elements: elements)
    }

    // MARK: - Initializer

    init(parent: Widget, element: BeamElement) {
        self.element = element

        super.init(parent: parent)

        addDisclosureLayer(at: NSPoint(x: bulletLayerPositionX, y: isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13))
        addBulletPointLayer(at: NSPoint(x: bulletLayerPositionX, y: isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13))

        element.$children
            .sink { [unowned self] elements in
                updateTextChildren(elements: elements)
            }.store(in: &scope)

        createActionLayer()
        createIndentLayer()

        subscribeToElement(element)

        setAccessibilityLabel("TextNode")
        setAccessibilityRole(.textArea)
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        self.element = element

        super.init(editor: editor)

        addDisclosureLayer(at: NSPoint(x: bulletLayerPositionX, y: isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13))
        addBulletPointLayer(at: NSPoint(x: bulletLayerPositionX, y: isHeader ? firstLineBaseline - 8 : firstLineBaseline - 13))

        element.$children
            .sink { [unowned self] elements in
                updateTextChildren(elements: elements)
            }.store(in: &scope)

        createActionLayer()
        createIndentLayer()

        subscribeToElement(element)

        setAccessibilityLabel("TextNode")
        setAccessibilityRole(.textArea)
    }

    // MARK: - Setup UI

    override public func draw(in context: CGContext) {
        context.saveGState()
        context.translateBy(x: indent, y: 0)

        updateRendering()

        drawDebug(in: context)

        if selfVisible {
            context.saveGState(); defer { context.restoreGState() }

            drawSelection(in: context)
            drawText(in: context)

            if isEditing {
                drawCursor(in: context)
            }
        }
        context.restoreGState()
    }

    public func drawMarkee(_ context: CGContext, _ start: Int, _ end: Int, _ color: NSColor) {
        guard let textFrame = textFrame else { return }

        context.beginPath()
        let startLine = lineAt(index: start)!
        let endLine = lineAt(index: end)!
        let lineCount = textFrame.lines.count
        guard lineCount > startLine, lineCount > endLine else { return }
        let line1 = textFrame.lines[startLine]
        let line2 = textFrame.lines[endLine]
        let xStart = offsetAt(index: start)
        let xEnd = offsetAt(index: end)

        context.setFillColor(color.cgColor)

        if startLine == endLine {
            // Selection begins and ends on the same line:
            let markRect = NSRect(x: xStart, y: line1.frame.minY, width: xEnd - xStart, height: line1.bounds.height)
            context.addRect(markRect)
        } else {
            let markRect1 = NSRect(x: xStart, y: line1.frame.minY, width: textFrame.frame.width - xStart, height: line2.frame.minY - line1.frame.minY )
            context.addRect(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: 0, y: line1.frame.maxY, width: textFrame.frame.width, height: line2.frame.minY - line1.frame.maxY)
                context.addRect(markRect2)
            }

            let markRect3 = NSRect(x: 0, y: line1.frame.maxY, width: xEnd, height: CGFloat(line2.frame.maxY - line1.frame.maxY) + 1)
            context.addRect(markRect3)
        }

        context.drawPath(using: .fill)
    }

    override func updateChildrenLayout() {
        updateIndentLayer()
        var pos = NSPoint(x: childInset, y: self.contentsFrame.height)

        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - childInset
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)
            pos.y += childSize.height
        }

        // Disable action layer update to avoid motion glitch
        // when the global layer width is changed
        if !editor.isResizing {
            updateActionLayer(animate: true)
        } else {
            updateActionLayer(animate: false)
        }
    }

    func createIndentLayer() {
        let indentLayer = CALayer()
        indentLayer.backgroundColor = BeamColor.Editor.indentBackground.cgColor
        indentLayer.enableAnimations = false
        addLayer(Layer(name: "indentLayer", layer: indentLayer))
        updateIndentLayer()
    }

    func updateIndentLayer() {
        guard let indentLayer = layers["indentLayer"] else { return }
        let y = firstLineHeight + 8
        indentLayer.frame = NSRect(x: childInset - 0.5, y: y - 5, width: 1, height: frame.height - y - 5)
        indentLayer.layer.isHidden = children.isEmpty || !open
    }

    func invalidateText() {
        if parent == nil {
            _attributedString = nil
            return
        }
        if updateAttributedString() || elementText.isEmpty {
            invalidateRendering()
        }
    }

    func deepInvalidateText() {
        invalidateText()
        for c in children {
            guard let c = c as? TextNode else { continue }
            c.deepInvalidateText()
        }
    }

    func addDisclosureLayer(at point: NSPoint) {
        let disclosureLayer = ChevronButton("disclosure", open: open, changed: { [unowned self] value in
            self.open = value
            layers["indentLayer"]?.layer.isHidden = !value
        })
        disclosureLayer.layer.isHidden = true
        addLayer(disclosureLayer, origin: point)
    }

    func addBulletPointLayer(at point: NSPoint) {
        let bulletLayer = Layer(name: "bullet", layer: Layer.icon(named: "editor-bullet", color: BeamColor.Editor.bullet.nsColor))
        bulletLayer.layer.isHidden = true
        addLayer(bulletLayer, origin: point)
    }

    func drawSelection(in context: CGContext) {
        guard !readOnly else { return }

        //Draw Selection:
        if isEditing {
            if let range = markedTextRange {
                drawMarkee(context, range.lowerBound, range.upperBound, markedColor)
            }

            if !selectedTextRange.isEmpty {
                drawMarkee(context, selectedTextRange.lowerBound, selectedTextRange.upperBound, selectionColor)
            }
        }
    }

    func drawText(in context: CGContext) {
        // Draw the text:
        context.saveGState()

        guard let bulletLayer = self.layers["bullet"] else { return }
        guard let disclosureLayer = self.layers["disclosure"] as? ChevronButton else { return }

        if showDisclosureButton {
            bulletLayer.layer.isHidden = true
            disclosureLayer.layer.isHidden = false
        } else {
            bulletLayer.layer.isHidden = false
            disclosureLayer.layer.isHidden = true
        }

        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: firstLineBaseline)

        textFrame?.draw(context)
        context.restoreGState()
    }

    func drawCursor(in context: CGContext) {
        guard !readOnly, editor.hasFocus, editor.blinkPhase else { return }
        let cursorRect = rectAt(cursorPosition)

        context.beginPath()
        context.addRect(cursorRect)
        //let fill = RBFill()
        context.setFillColor(enabled ? color.cgColor : disabledColor.cgColor)

        //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
        context.drawPath(using: .fill)
    }

    override func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            contentsFrame = NSRect()

            if selfVisible {
                emptyTextFrame = nil
                let attrStr = attributedString
                let textFrame = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: availableWidth - childInset)
                self.textFrame = textFrame
                contentsFrame = textFrame.frame

                if attrStr.string.isEmpty {
                    let dummyText = buildAttributedString(for: BeamText(text: "Dummy!"))
                    let fakelayout = Font.draw(string: dummyText, atPosition: NSPoint(x: indent, y: 0), textWidth: availableWidth - childInset)

                    self.emptyTextFrame = fakelayout
                    contentsFrame = fakelayout.frame
                }

                if self as? TextRoot == nil {
                    switch elementKind {
                        case .heading(1):
                            contentsFrame.size.height += 8
                        case .heading(2):
                            contentsFrame.size.height += 4
                        default:
                            contentsFrame.size.height -= 5
                    }
                }
            }

            contentsFrame.size.width = availableWidth
            contentsFrame = contentsFrame.rounded()

            invalidatedRendering = false
        }

        computedIdealSize = contentsFrame.size

        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
        }
    }

    func createActionLayer() {
        let actionLayer = ShortcutLayer(name: "CmdEnterLayer", text: "Search", icons: ["editor-cmdreturn"]) {
            self.editor.onStartQuery(self)
        }
        actionLayer.layer.isHidden = true
        addLayer(actionLayer, origin: CGPoint(x: availableWidth + childInset + actionLayerPadding, y: firstLineBaseline), global: false)
    }

    func updateActionLayer(animate: Bool) {
        guard let actionLayer = layers["CmdEnterLayer"] else { return }
        let actionLayerYPosition = isHeader ? (contentsFrame.height / 2) - actionLayer.frame.height : 0
        if animate {
            actionLayer.frame = CGRect(x: availableWidth + childInset + actionLayerPadding, y: actionLayerYPosition, width: actionLayer.frame.width, height: actionLayer.frame.height)
        } else {
            CATransaction.disableAnimations {
                actionLayer.frame = CGRect(x: availableWidth + childInset + actionLayerPadding, y: actionLayerYPosition, width: actionLayer.frame.width, height: actionLayer.frame.height)
            }
        }
    }

    // MARK: - Methods TextNode

    override func delete() {
        guard let parent = parent as? TextNode else { return }
        parent.element.removeChild(element)
    }

    override func insert(node: Widget, after existingNode: Widget) -> Bool {
        guard let node = node as? TextNode, let existingNode = existingNode as? TextNode else { fatalError () }
        element.insert(node.element, after: existingNode.element)
        invalidateLayout()
        return true
    }

    @discardableResult
    override func insert(node: Widget, at pos: Int) -> Bool {
        guard let node = node as? TextNode else { fatalError () }
        element.insert(node.element, at: pos)
        invalidateLayout()
        return true
    }

    func sourceIndexFor(displayIndex: Int) -> Int {
        return displayIndex
    }

    func displayIndexFor(sourceIndex: Int) -> Int {
        return sourceIndex
    }

    func beginningOfLineFromPosition(_ position: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard textFrame.lines.count > 1 else { return 0 }
        if let l = lineAt(index: position) {
            return textFrame.lines[l].range.lowerBound
        }
        return 0
    }

    func endOfLineFromPosition(_ position: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard textFrame.lines.count != 1 else {
            return text.count
        }
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

    func fold() {
        if children.isEmpty {
            guard let p = parent as? TextNode else { return }
            p.fold()
            p.focus()
            return
        }

        open = false
    }

    func unfold() {
        guard !children.isEmpty else { return }
        open = true
    }

    override func onFocus() {
        super.onFocus()
        guard !text.isEmpty else { return }
    }

    override func onUnfocus() {
        super.onUnfocus()
        updateActionLayerVisibility(hidden: true)
    }

    private func updateActionLayerVisibility(hidden: Bool) {
        guard let actionLayer = layers["CmdEnterLayer"] else { return }
        actionLayer.layer.isHidden = hidden
    }

    private func isHoveringText() -> Bool {
        let isMouseInsideFormatter = editor.inlineFormatter?.isMouseInsideView == true || editor.popover != nil
        return hover && !isMouseInsideFormatter
    }

    // MARK: - Mouse Events
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    override func mouseDown(mouseInfo: MouseInfo) -> Bool {

        guard !mouseInfo.rightMouse else {
            return handleRightMouseDown(mouseInfo: mouseInfo)
        }

        if contentsFrame.contains(mouseInfo.position) {
            updateActionLayerVisibility(hidden: false)

            let clickPos = positionAt(point: mouseInfo.position)

            if let link = linkAt(point: mouseInfo.position) {
                openExternalLink(link: link, element: element)
                return true
            }

            if let link = internalLinkAt(point: mouseInfo.position) {
                editor.cancelInternalLink()
                editor.openCard(link)
                return true
            }

            if mouseInfo.event.clickCount == 1 && editor.inlineFormatter != nil {
                root?.cancelSelection()
                focus(cursorPosition: clickPos)
                dragMode = .select(cursorPosition)

                debounceClickTimer = Timer.scheduledTimer(withTimeInterval: debounceClickInterval, repeats: false, block: { [weak self] (_) in
                    guard let self = self else { return }
                    self.editor.dismissPopoverOrFormatter()
                })
                return true
            } else if mouseInfo.event.clickCount == 1 && mouseInfo.event.modifierFlags.contains(.shift) {
                dragMode = .select(cursorPosition)
                root?.extendSelection(to: clickPos)
                editor.showInlineFormatterOnKeyEventsAndClick()
                return true
            } else if mouseInfo.event.clickCount == 1 {
                root?.cancelSelection()
                focus(cursorPosition: clickPos)
                dragMode = .select(cursorPosition)
                editor.initAndShowPersistentFormatter()
                return true
            } else if mouseInfo.event.clickCount == 2 {
                debounceClickTimer?.invalidate()
                root?.wordSelection(from: clickPos)
                if !selectedTextRange.isEmpty {
                    editor.cursorStartPosition = cursorPosition
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
                return true
            } else {
                debounceClickTimer?.invalidate()
                root?.selectAll()
                editor.detectFormatterType()

                if root?.state.nodeSelection != nil {
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
                return true
            }
        }
        return false
    }

    private func handleRightMouseDown(mouseInfo: MouseInfo) -> Bool {

        if contentsFrame.contains(mouseInfo.position) {
            let clickPos = positionAt(point: mouseInfo.position)
            // default right click behavior: select word

            let (linkRange, _) = linkRangeAt(point: mouseInfo.position)
            if let linkRange = linkRange {
                // open link right menu
                focus(cursorPosition: linkRange.end)
                let selectRange = linkRange.position..<linkRange.end
                root?.selectedTextRange = selectRange
                cursor = .arrow
                editor.showLinkFormatterForSelection(mousePosition: mouseInfo.position, showMenu: true)
            } else {
                focus(cursorPosition: clickPos)
                root?.wordSelection(from: clickPos)
                if !selectedTextRange.isEmpty {
                    editor.cursorStartPosition = cursorPosition
                    editor.showInlineFormatterOnKeyEventsAndClick()
                }
            }
            return true
        }
        return false
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        editor.detectFormatterType()

        if mouseIsDragged {
            editor.detectFormatterType()
            editor.showOrHideInlineFormatter(isPresent: true)
            mouseIsDragged = false
        }
        return false
    }

    private func handleMouseHoverState(mouseInfo: MouseInfo) {
        let isMouseInContentFrame = contentsFrame.contains(mouseInfo.position)
        let isMouseInsideFormatter = editor.inlineFormatter?.isMouseInsideView == true || editor.popover != nil
        let mouseHasChangedTextPosition = lastHoverMouseInfo?.position != mouseInfo.position
        if mouseHasChangedTextPosition && isMouseInContentFrame {
            let link = linkAt(point: mouseInfo.position)
            let internalLink = internalLinkAt(point: mouseInfo.position)

            if link != nil {
                let (linkRange, linkFrame) = linkRangeAt(point: mouseInfo.position)
                if let linkRange = linkRange, let currentNode = widgetAt(point: mouseInfo.position) as? TextNode, !isMouseInsideFormatter {
                    invalidateText()
                    cursor = .pointingHand
                    if let positionInText = indexAt(point: mouseInfo.position, limitToTextString: false),
                       BeamText.isPositionOnLinkArrow(positionInText, in: linkRange) {
                        editor.linkStartedHovering(
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
                invalidateText()
            }
        }
        lastHoverMouseInfo = mouseInfo
        if isMouseInsideFormatter {
            cursor = nil
        }
    }

    override func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        self.handleMouseHoverState(mouseInfo: mouseInfo)
        return false
    }

    override func mouseDragged(mouseInfo: MouseInfo) -> Bool {
        let p = positionAt(point: mouseInfo.position)
        root?.cursorPosition = p

        switch dragMode {
        case .none:
            return false
        case .select(let o):
            root?.selectedTextRange = text.clamp(p < o ? cursorPosition..<o : o..<cursorPosition)
            mouseIsDragged = root?.state.nodeSelection == nil

            // When more than one bullet is selected hide & disable cmd+enter action
            if let nodeSelection = root?.state.nodeSelection, nodeSelection.nodes.count > 1 {
                updateActionLayerVisibility(hidden: true)
            } else {
                updateActionLayerVisibility(hidden: false)
            }

            // Set cursor start position
            if editor.cursorStartPosition == 0 { editor.cursorStartPosition = cursorPosition }

            // Update inline formatter on drag
            if root?.state.nodeSelection == nil { editor.updateInlineFormatterOnDrag(isDragged: true) }
        }
        invalidate()

        return true
    }

    // MARK: - Text & Cursor Position

    public func lineAt(point: NSPoint) -> Int {
        guard let textFrame = textFrame, !textFrame.lines.isEmpty else { return 0 }
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

    public func position(after index: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        return textFrame.position(after: index)
    }

    public func position(before index: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        return textFrame.position(before: index)
    }

    public func positionAt(point: NSPoint) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard !textFrame.lines.isEmpty else { return 0 }
        let line = lineAt(point: point)
        let lines = textFrame.lines
        let l = lines[line]
        let displayIndex = l.stringIndexFor(position: point)
        let res = sourceIndexFor(displayIndex: displayIndex)

        return res
    }

    public func indexAt(point: NSPoint, limitToTextString: Bool = true) -> Int? {
        guard let textFrame = textFrame else { return nil }
        guard !textFrame.lines.isEmpty else { return nil }
        let line = lineAt(point: point)
        guard line >= 0 else { return nil }
        let l = textFrame.lines[line]
        guard l.frame.minX < point.x && l.frame.maxX > point.x else { return nil } // point is outside the line
        let displayIndex = l.stringIndexFor(position: point)
        if !limitToTextString {
            // can be outside of text string for decoration element like link arrow
            return displayIndex
        }
        return min(displayIndex, text.count - 1)
    }

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

    func linkRangeAt(point: NSPoint) -> (BeamText.Range?, NSRect?) {
        guard let textFrame = textFrame else { return (nil, nil) }
        guard !textFrame.lines.isEmpty else { return (nil, nil) }
        let line = lineAt(point: point)
        guard line >= 0 else { return (nil, nil) }
        let l = textFrame.lines[line]
        guard let pos = indexAt(point: point) else { return (nil, nil) }

        let range = elementText.rangeAt(position: pos)
        guard nil != range.attributes.firstIndex(where: { attrib -> Bool in
            attrib.rawValue == BeamText.Attribute.link("").rawValue
        }) else { return (nil, nil) }

        let start = range.position
        let end = range.end
        let startOffset = offsetAt(index: start)
        let endOffset = offsetAt(index: end)

        let linkFrame = NSRect(x: startOffset, y: l.frame.minY, width: endOffset - startOffset, height: l.frame.height)
        return (range, linkFrame)
    }

    public func internalLinkAt(point: NSPoint) -> String? {
        guard let textFrame = textFrame else { return nil }
        let line = lineAt(point: point)
        guard line >= 0, !textFrame.lines.isEmpty else { return nil }
        let l = textFrame.lines[line]
        guard l.frame.minX <= point.x && l.frame.maxX >= point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: point)
        let pos = min(displayIndex, attributedString.length - 1)
        return attributedString.attribute(.link, at: pos, effectiveRange: nil) as? String
    }

    public func offsetAt(index: Int) -> CGFloat {
        guard let textFrame = emptyTextFrame ?? self.textFrame else { return 0 }
        guard !textFrame.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        guard let line = lineAt(index: displayIndex) else { return 0 }
        let textLine = textFrame.lines[line]
        let positionInLine = displayIndex
        let result = textLine.offsetFor(index: positionInLine)
        return CGFloat(result)
    }

    public func offsetAndFrameAt(index: Int) -> (CGFloat, NSRect) {
        guard let textFrame = textFrame else { return (0, .zero) }
        let displayIndex = displayIndexFor(sourceIndex: index)

        guard !textFrame.lines.isEmpty,
              let line = lineAt(index: displayIndex) else { return (0, .zero) }

        let textLine = textFrame.lines[line]
        let positionInLine = displayIndex
        let result = textLine.offsetFor(index: positionInLine)

        return (CGFloat(result), textLine.frame)
    }

    public func positionAbove(_ position: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard let l = lineAt(index: position), l > 0 else { return 0 }
        let offset = offsetAt(index: position)
        let indexAbove = textFrame.lines[l - 1].stringIndexFor(position: NSPoint(x: offset, y: 0))
        return sourceIndexFor(displayIndex: indexAbove)
    }

    public func positionBelow(_ position: Int) -> Int {
        guard let textFrame = textFrame else { return 0 }
        guard let l = lineAt(index: position), l < textFrame.lines.count - 1 else { return text.count }
        let offset = offsetAt(index: position)
        let indexBelow = textFrame.lines[l + 1].stringIndexFor(position: NSPoint(x: offset, y: 0))
        return sourceIndexFor(displayIndex: indexBelow)
    }

    public func isOnFirstLine(_ position: Int) -> Bool {
        guard let l = lineAt(index: position) else { return false }
        return l == 0
    }

    public func isOnLastLine(_ position: Int) -> Bool {
        guard let textFrame = textFrame else { return true }
        guard textFrame.lines.count > 1 else { return true }
        guard let l = lineAt(index: position) else { return false }
        return l == textFrame.lines.count - 1
    }

    public func rectAt(_ position: Int) -> NSRect {
        updateRendering()
        let textLine: TextLine? = {
            if let emptyLayout = emptyTextFrame {
                return emptyLayout.lines[0]
            }

            guard let cursorLine = lineAt(index: position <= 0 ? 0 : position) else { fatalError() }
            return textFrame?.lines[cursorLine] ?? nil
        }()

        guard let line = textLine else { return NSRect.zero }
        let pos = position
        let x1 = offsetAt(index: pos)
        let cursorRect = NSRect(x: x1, y: line.frame.minY, width: position == text.count ? bigCursorWidth : smallCursorWidth, height: line.bounds.height)

        return cursorRect
    }

    public func indexOnLastLine(atOffset x: CGFloat) -> Int {
        guard let lines = textFrame?.lines else { return 0 }
        guard !lines.isEmpty else { return 0 }
        guard let line = lines.last else { return 0 }
        let displayIndex = line.stringIndexFor(position: NSPoint(x: x, y: 0))
        if displayIndex == line.range.upperBound {
            return endOfLineFromPosition(displayIndex)
        }
        let sourceIndex = sourceIndexFor(displayIndex: displayIndex)
        return sourceIndex
    }

    public func indexOnFirstLine(atOffset x: CGFloat) -> Int {
        guard let lines = textFrame?.lines else { return 0 }
        guard !lines.isEmpty else { return 0 }
        guard let line = lines.first else { return 0 }
        let displayIndex = line.stringIndexFor(position: NSPoint(x: x, y: 0))
        if displayIndex == line.range.upperBound {
            return endOfLineFromPosition(displayIndex)
        }
        let sourceIndex = sourceIndexFor(displayIndex: displayIndex)
        return sourceIndex
    }

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

    private func buildAttributedString(for beamText: BeamText) -> NSMutableAttributedString {

        switch elementKind {
        case .heading(1):
            fontSize = 22 // TODO: Change later (isBig ? 26 : 22)
        case .heading(2):
            fontSize = 18 // TODO: Change later (isBig ? 22 : 18)
        default:
            fontSize = 15 // TODO: Change later (isBig ? 17 : 15)
        }

        var mouseInteraction: MouseInteraction?
        if let hoverMouse = lastHoverMouseInfo, isHoveringText() {
            if let pos = indexAt(point: hoverMouse.position, limitToTextString: false) {
                let nsrange = NSRange(location: pos, length: 1)
                mouseInteraction = MouseInteraction(type: MouseInteractionType.hovered, range: nsrange)
            }
        }

        let str = beamText.buildAttributedString(fontSize: fontSize, cursorPosition: cursorPosition, elementKind: elementKind, mouseInteraction: mouseInteraction)
        let paragraphStyle = NSMutableParagraphStyle()
        //        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = interlineFactor
        paragraphStyle.lineSpacing = 40
        paragraphStyle.paragraphSpacingBefore = 0
        paragraphStyle.paragraphSpacing = 10

        str.addAttribute(.paragraphStyle, value: paragraphStyle, range: str.wholeRange)
        return str
    }

    private func buildAttributedString() -> NSAttributedString {
        if elementText.isEmpty {
            let placeholderAttributedStr = buildAttributedString(for: placeholder)
            placeholderAttributedStr.addAttributes([NSAttributedString.Key.foregroundColor: BeamColor.Generic.placeholder.cgColor])
            return placeholderAttributedStr
        }
        return buildAttributedString(for: elementText)
    }

    internal func actionLayerMousePosition(from mouseInfo: MouseInfo) -> NSPoint {
        return NSPoint(x: indent + mouseInfo.position.x, y: mouseInfo.position.y)
    }

    func openExternalLink(link: URL, element: BeamElement) {
        editor.cancelInternalLink()
        editor.openURL(link, element)
    }

    func nextVisibleTextNode() -> TextNode? {
        var node = nextVisible()
        while node != nil {
            if let textNode = node as? TextNode {
                return textNode
            }
            let next = node?.nextVisible()
            assert(next != node)
            node = next
        }

        return nil
    }

    func previousVisibleTextNode() -> TextNode? {
        var node = previousVisible()
        while node != nil {
            if let textNode = node as? TextNode {
                return textNode
            }
            let previous = node?.previousVisible()
            assert(previous != node)
            node = previous
        }

        return nil
    }

    func isAbove(node: TextNode) -> Bool {
        guard !(node == self) else { return false }
        let allParents1 = [Widget](allParents.reversed()) + [self]
        guard !allParents1.contains(node) else { return false }
        let allParents2 = [Widget](node.allParents.reversed()) + [node]
        guard !allParents2.contains(self) else { return true }

        // Both nodes must share the same root. If you crash here, you are comparing nodes that are NOT in the same tree...
        assert(allParents1.first == allParents2.first)

        var index = 0
        // find first common parent:
        let count = min(allParents1.count, allParents2.count)

        while allParents1[index] == allParents2[index] {
            let nextIndex = index + 1

            guard nextIndex < count else {
                return (allParents1[index].indexInParent!) < (allParents2[index].indexInParent!)
            }
            index = nextIndex
        }

        return (allParents1[index].indexInParent ?? -1) < (allParents2[index].indexInParent ?? -1)
    }

    public func deepestTextNodeChild() -> TextNode {
        for c in children.reversed() {
            if let c = c as? TextNode {
                return c.deepestTextNodeChild()
            }
        }
        return self
    }

    override func dumpWidgetTree(_ level: Int = 0) {
        let tabs = String.tabs(level)
        //swiftlink:disable:next print
        print("\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers - element id: \(element.id) [\(elementText.text)]\(layer.superlayer == nil ? " DETTACHED" : "")")
        for c in children {
            c.dumpWidgetTree(level + 1)
        }
    }

    override var mainLayerName: String {
        "TextNode - \(element.id.uuidString)"
    }

    public override func accessibilityString(for range: NSRange) -> String? {
        return text.substring(range: range.lowerBound ..< range.upperBound)
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
        guard let line = textFrame?.lines[line] else { return NSRange() }
        let range = line.range
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

    func subscribeToElement(_ element: BeamElement) {
        elementScope.removeAll()

        element.$text
            .dropFirst()
            .sink { [unowned self] newValue in
                elementText = newValue
                self.invalidateText()
            }.store(in: &elementScope)

        element.$kind
            .dropFirst()
            .sink { [unowned self] newValue in
                elementKind = newValue
                self.invalidateText()
            }.store(in: &elementScope)

        element.$open
            .sink { [unowned self] newValue in
                if open != newValue {
                    open = newValue
                }
            }.store(in: &elementScope)

        elementText = element.text
        elementKind = element.kind
    }
}
