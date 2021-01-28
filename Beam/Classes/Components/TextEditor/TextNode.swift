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

// swiftlint:disable:next type_body_length
public class TextNode: Widget {

    var element: BeamElement { didSet {
        elementTextScope = element.$text.sink { [unowned self] newValue in
            elementText = newValue
            self.invalidateText()
        }

        elementKindScope = element.$kind.sink { [unowned self] newValue in
            elementKind = newValue
            self.invalidateText()
        }

        elementText = element.text
        elementKind = element.kind
    }}

    var elementTextScope: Cancellable?
    var elementKindScope: Cancellable?

    var elementText: BeamText
    var elementKind: ElementKind

    var layout: TextFrame?
    var emptyLayout: TextFrame?
    var disclosurePressed = false
    var frameAnimation: FrameAnimation?
    var frameAnimationCancellable = Set<AnyCancellable>()

    var interlineFactor = CGFloat(1.3)
    var interNodeSpacing = CGFloat(4)
    var indent: CGFloat {
        selfVisible ? 25 : 0
    }
    var fontSize = CGFloat(17)

    override var contentsScale: CGFloat {
        didSet {
            guard let actionLayer = actionLayer else { return }
            actionLayer.contentsScale = contentsScale
            actionTextLayer.contentsScale = contentsScale
            actionImageLayer.contentsScale = contentsScale
        }
    }

    var text: BeamText {
        get { element.text }
        set {
            guard element.text != newValue else { return }
            if !newValue.isEmpty && actionImageLayer.opacity == 0 { actionImageLayer.opacity = 1 }
            if newValue.isEmpty { resetActionLayers() }

            element.text = newValue
            element.note?.modifiedByUser()
            invalidateText()
        }
    }

    var placeholder = BeamText() {
        didSet {
            guard oldValue != text else { return }
            invalidateText()
        }
    }

    var strippedText: String {
        attributedString.string
    }

    var fullStrippedText: String {
        children.reduce(attributedString.string) { partial, node -> String in
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

    internal override var children: [Widget] {
        get {
            return element.children.map { childElement -> TextNode in
                editor.nodeFor(childElement)
            }
        }
        set {
            fatalError()
        }
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
    var markedTextRange: Range<Int> { root?.markedTextRange ?? 0..<0 }
    var cursorsStartPosition: Int { root?.cursorPosition ?? 0 }
    var cursorPosition: Int { root?.cursorPosition ?? 0 }

    var disclosureButtonFrame: NSRect {
        let r = NSRect(x: 2, y: -4, width: 16, height: 16)
        return r.offsetBy(dx: 0, dy: r.height).insetBy(dx: -4, dy: -4)
    }

    var showDisclosureButton: Bool {
        depth > 0 && !children.isEmpty
    }

    var showIdentationLine: Bool {
        return depth == 1
    }

    var _parent: Widget?
    override var parent: Widget? {
        get {
            // If the parent has been forced on us:
            if _parent != nil {
                return _parent
            }

            // Otherwise use the document's information
            guard let p = element.parent else { return nil }
            return editor.nodeFor(p)
        }
        set {
            // force the parent for this node (happens when using proxies)
            _parent = newValue
        }
    }

    var readOnly: Bool = false
    var isEditing: Bool { root?.node === self && root?.state.nodeSelection == nil }

    var firstLineHeight: CGFloat {
        let layout = emptyLayout ?? self.layout
        return layout?.lines.first?.bounds.height ?? CGFloat(fontSize * interlineFactor)
    }
    var firstLineBaseline: CGFloat {
        let layout = emptyLayout ?? self.layout
        if let firstLine = layout?.lines.first {
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

    internal var actionLayer: CALayer?
    private var actionLayerIsHovered = false
    private var icon = NSImage(named: "editor-cmdreturn")

    private let actionImageLayer = CALayer()
    private let actionTextLayer = CATextLayer()
    private let actionLayerFrame = CGRect(x: 30, y: 0, width: 80, height: 20)

    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer

    init(editor: BeamTextEdit, element: BeamElement) {
        self.element = element

        elementText = element.text
        elementKind = element.kind

        super.init(editor: editor)

        element.$children
            .dropFirst()
            .sink { [unowned self] _ in
            self.invalidateLayout()
        }.store(in: &scope)

        createActionLayer()

        var inInit = true
        elementTextScope = element.$text.sink { [unowned self] newValue in
            guard !inInit else { return }
            elementText = newValue
            self.invalidateText()
        }

        elementKindScope = element.$kind.sink { [unowned self] newValue in
            guard !inInit else { return }
            elementKind = newValue
            self.invalidateText()
        }
        inInit = false
    }

    deinit {
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
        context.beginPath()
        let startLine = lineAt(index: start)!
        let endLine = lineAt(index: end)!
        let line1 = layout!.lines[startLine]
        let line2 = layout!.lines[endLine]
        let xStart = offsetAt(index: start)
        let xEnd = offsetAt(index: end)

        context.setFillColor(color.cgColor)

        if startLine == endLine {
            // Selection begins and ends on the same line:
            let markRect = NSRect(x: xStart, y: line1.frame.minY, width: xEnd - xStart, height: line1.bounds.height)
            context.addRect(markRect)
        } else {
            let markRect1 = NSRect(x: xStart, y: line1.frame.minY, width: frame.width - xStart, height: line2.frame.minY - line1.frame.minY )
            context.addRect(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: 0, y: line1.frame.maxY, width: frame.width, height: line2.frame.minY - line1.frame.maxY)
                context.addRect(markRect2)
            }

            let markRect3 = NSRect(x: 0, y: line1.frame.maxY, width: xEnd, height: CGFloat(line2.frame.maxY - line1.frame.maxY) + 1)
            context.addRect(markRect3)
        }

        context.drawPath(using: .fill)
    }

    override func updateChildrenLayout() {
        var pos = NSPoint(x: childInset, y: self.contentsFrame.height)

        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - childInset
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }

        updateActionLayer()
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

    func drawDisclosure(at point: NSPoint, in context: CGContext) {
        let symbol = open ? "editor-arrow_down" : "editor-arrow_right"
        drawImage(named: symbol, at: point, in: context, size: CGRect(x: 0, y: firstLineBaseline, width: 16, height: 16))
    }

    func drawBulletPoint(at point: NSPoint, in context: CGContext) {
        drawImage(named: "editor-bullet", at: point, in: context, size: CGRect(x: 0, y: firstLineBaseline, width: 16, height: 16))
    }

    func drawSelection(in context: CGContext) {
        guard !readOnly else { return }

        //Draw Selection:
        if isEditing {
            if !markedTextRange.isEmpty {
                drawMarkee(context, markedTextRange.lowerBound, markedTextRange.upperBound, markedColor)
            } else if !selectedTextRange.isEmpty {
                drawMarkee(context, selectedTextRange.lowerBound, selectedTextRange.upperBound, selectionColor)
            }
        }
    }

    func drawText(in context: CGContext) {
        // Draw the text:
        context.saveGState()
        if !children.isEmpty {
            if showDisclosureButton {
                context.saveGState()
                if showIdentationLine {
                    context.setFillColor(NSColor.editorTextRectangleBackgroundColor.cgColor)
                    let y = contentsFrame.height
                    let r = NSRect(x: 5, y: y + 3, width: 1, height: currentFrameInDocument.height - y - 6)
                    context.fill(r)
                }
                context.restoreGState()
            }
        }

        let offset = NSPoint(x: 0, y: firstLineBaseline)

        if showDisclosureButton {
            drawDisclosure(at: NSPoint(x: offset.x, y: -(firstLineBaseline - 14)), in: context)
        } else {
            drawBulletPoint(at: NSPoint(x: 0, y: -(firstLineBaseline - 14)), in: context)
        }

        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: firstLineBaseline)

        layout?.draw(context)
        context.restoreGState()
    }

    func drawCursor(in context: CGContext) {
        guard !readOnly, editor.hasFocus, editor.blinkPhase else { return }

        // Otherwise, draw the cursor at a real position
        let line: TextLine = {
            if let emptyLayout = emptyLayout {
                return emptyLayout.lines[0]
            }

            guard let cursorLine = lineAt(index: cursorPosition <= 0 ? 0 : cursorPosition) else { fatalError() }
            return layout!.lines[cursorLine]
        }()

        let pos = cursorPosition
        let x1 = offsetAt(index: pos)
        let cursorRect = NSRect(x: x1, y: line.frame.minY, width: cursorPosition == text.count ? bigCursorWidth : smallCursorWidth, height: line.bounds.height)

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
                emptyLayout = nil
                let attrStr = attributedString
                let layout = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: (availableWidth - actionLayerFrame.width) - actionLayerFrame.minX)
                self.layout = layout
                contentsFrame = layout.frame

                if attrStr.string.isEmpty {
                    let dummyText = buildAttributedString(for: BeamText(text: "Dummy!"))
                    let fakelayout = Font.draw(string: dummyText, atPosition: NSPoint(x: indent, y: 0), textWidth: (availableWidth - actionLayerFrame.width) - actionLayerFrame.minX)

                    self.emptyLayout = fakelayout
                    contentsFrame = fakelayout.frame
                }

                if self as? TextRoot == nil {
                    contentsFrame.size.height += interNodeSpacing
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
        actionLayer = CALayer()
        guard let actionLayer = actionLayer else { return }

        icon = icon?.fill(color: .editorSearchNormal)

        actionImageLayer.opacity = 0
        actionImageLayer.frame = CGRect(x: 0, y: 2, width: 20, height: 16)
        actionImageLayer.contents = icon?.cgImage

        actionTextLayer.opacity = 0
        actionTextLayer.font = NSFont.systemFont(ofSize: 0, weight: .medium)
        actionTextLayer.fontSize = 10
        actionTextLayer.frame = CGRect(x: 15, y: 3.5, width: 100, height: 20)
        actionTextLayer.string = "to search"
        actionTextLayer.foregroundColor = NSColor.editorSearchNormal.cgColor

        actionLayer.frame = CGRect(x: actionLayerFrame.minX, y: 0, width: actionLayerFrame.width, height: actionLayerFrame.height)

        actionLayer.addSublayer(actionTextLayer)
        actionLayer.addSublayer(actionImageLayer)

        layer.addSublayer(actionLayer)
    }

    func updateActionLayer() {
        CATransaction.disableAnimations {
            let actionLayerYPosition = isHeader ? (contentsFrame.height / 2) - actionLayerFrame.height : 0
            actionLayer?.frame = CGRect(x: (availableWidth - actionLayerFrame.width) + actionLayerFrame.minX, y: actionLayerYPosition, width: actionLayerFrame.width, height: actionLayerFrame.height)
        }
    }

    // MARK: - Methods TextNode

    override func addChild(_ child: Widget) {
        guard let child = child as? TextNode else { return }
        element.addChild(child.element)
        invalidateLayout()
    }

    override func removeChild(_ child: Widget) {
        guard let child = child as? TextNode else { return }
        element.removeChild(child.element)
        invalidateLayout()
    }

    override func delete() {
        parent?.removeChild(self)
        editor.removeNode(self)
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

    func cancelFrameAnimation() {
        frameAnimation = nil
        frameAnimationCancellable.removeAll()
    }

    func sourceIndexFor(displayIndex: Int) -> Int {
        return displayIndex
    }

    func displayIndexFor(sourceIndex: Int) -> Int {
        return sourceIndex
    }

    func beginningOfLineFromPosition(_ position: Int) -> Int {
        if let l = lineAt(index: position) {
            return layout!.lines[l].range.lowerBound
        }
        return 0
    }

    func endOfLineFromPosition(_ position: Int) -> Int {
        guard layout?.lines.count != 1 else {
            return text.count
        }
        if let l = lineAt(index: position) {
            let off = l < layout!.lines.count - 1 ? -1 : 0
            return layout!.lines[l].range.upperBound + off
        }
        return text.count
    }

    func currentSelectionWithFullSentences() -> String {
        let selectionStringRange = text.text.range(from: selectedTextRange)
        return text.text.sentences(around: selectionStringRange)
    }

    func fold() {
        if children.isEmpty {
            guard let p = parent as? TextNode else { return }
            p.fold()
            root?.node = p
            root?.cursorPosition = 0
            return
        }

        open = false
    }

    func unfold() {
        guard !children.isEmpty else { return }
        open = true
    }

    override func focus() {
        super.focus()
        guard !text.isEmpty else { return }
        showHoveredActionLayers(false)
    }

    override func unfocus() {
        super.unfocus()
        resetActionLayers()
    }

    // MARK: - Mouse Events
    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        assert(inVisibleBranch)
        if showDisclosureButton && disclosureButtonFrame.contains(mouseInfo.position) {
            disclosurePressed = true
            return true
        }

        // Start new query when the action layer is pressed.
        guard let actionLayer = actionLayer else { return false }
        let position = actionLayerMousePosition(from: mouseInfo)

        if isEditing && !actionLayer.isHidden && actionLayerIsHovered && actionLayer.frame.contains(position) {
            editor.onStartQuery(self)
            return true
        }

        if let link = linkAt(point: mouseInfo.position) {
            editor.cancelInternalLink()
            editor.openURL(link)
            return true
        }

        if let link = internalLinkAt(point: mouseInfo.position) {
            editor.cancelInternalLink()
            editor.openCard(link)
            return true
        }

        if contentsFrame.contains(mouseInfo.position) {
            let clickPos = positionAt(point: mouseInfo.position)

            if mouseInfo.event.clickCount == 1 && editor.inlineFormatter != nil {
                self.editor.dismissPopoverOrFormatter()
                root?.cursorPosition = clickPos
                root?.cancelSelection()
            } else if mouseInfo.event.clickCount == 1 {
                if mouseInfo.event.modifierFlags.contains(.shift) {
                    dragMode = .select(cursorPosition)
                    root?.extendSelection(to: clickPos)
                    editor.initAndUpdateInlineFormatter()
                    return true
                } else {
                    root?.cursorPosition = clickPos
                    root?.cancelSelection()
                    dragMode = .select(cursorPosition)
                }

                return true
            } else if mouseInfo.event.clickCount == 2 {
                root?.wordSelection(from: clickPos)
                editor.initAndUpdateInlineFormatter()
                return true
            } else {
                root?.doCommand(.selectAll)
                return true
            }
        }

        return false
    }

    override func mouseUp(mouseInfo: MouseInfo) -> Bool {
        editor.detectFormatterType()

        if disclosurePressed && disclosureButtonFrame.contains(mouseInfo.position) {
            disclosurePressed = false
            open.toggle()

            if !open && root?.node.allParents.contains(self) ?? false {
                root?.focus(node: self)
            }
            return true
        }
        return false
    }

    override func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        guard let actionLayer = actionLayer else { return false }

        let position = actionLayerMousePosition(from: mouseInfo)
        let hasTextAndEditable = !text.isEmpty && isEditing && editor.hasFocus

        // Show image & text layers
        if hasTextAndEditable && contentsFrame.contains(position) && actionLayer.frame.contains(position) {
            showHoveredActionLayers(true)
            return true
        } else if hasTextAndEditable && contentsFrame.contains(position) {
            showHoveredActionLayers(false)
            return true
        }

        // Reset action layers
        if !contentsFrame.contains(position) && isEditing && editor.hasFocus {
            showHoveredActionLayers(false)
            return true
        }

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
            editor.detectFormatterType()
            editor.initAndUpdateInlineFormatter(isDragged: true)
        }
        invalidate()

        return true
    }

    // MARK: - Text & Cursor Position

    public func lineAt(point: NSPoint) -> Int {
        guard let layout = layout else { return 0 }
        let y = point.y
        if y >= contentsFrame.height {
            let v = layout.lines.count - 1
            return max(v, 0)
        } else if y < 0 {
            return 0
        }

        for (i, l) in layout.lines.enumerated() where point.y < l.frame.minY + CGFloat(fontSize) {
            return i
        }

        return min(Int(y / CGFloat(fontSize)), layout.lines.count - 1)
    }

    public func lineAt(index: Int) -> Int? {
        guard index >= 0 else { return nil }
        guard let layout = layout else { return 0 }
        guard !layout.lines.isEmpty else { return 0 }
        for (i, l) in layout.lines.enumerated() where index < l.range.lowerBound {
            return i - 1
        }
        if !layout.lines.isEmpty {
            return layout.lines.count - 1
        }
        return nil
    }

    public func position(at index: String.Index) -> Int {
        return text.position(at: index)
    }

    public func position(after index: Int) -> Int {
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        let newDisplayIndex = attributedString.string.position(after: displayIndex)
        let newIndex = sourceIndexFor(displayIndex: newDisplayIndex)
        return newIndex
    }

    public func position(before index: Int) -> Int {
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        let newDisplayIndex = attributedString.string.position(before: displayIndex)
        let newIndex = sourceIndexFor(displayIndex: newDisplayIndex)
        return newIndex
    }

    public func positionAt(point: NSPoint) -> Int {
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let line = lineAt(point: point)
        let lines = layout!.lines
        let l = lines[line]
        let displayIndex = l.stringIndexFor(position: point)
        let res = sourceIndexFor(displayIndex: displayIndex)

        return res
    }

    public func linkAt(point: NSPoint) -> URL? {
        guard layout != nil, !layout!.lines.isEmpty else { return nil }
        let line = lineAt(point: point)
        guard line >= 0 else { return nil }
        let l = layout!.lines[line]
        guard l.frame.minX < point.x && l.frame.maxX > point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: point)
        let pos = min(displayIndex, attributedString.length - 1)
        return attributedString.attribute(.link, at: pos, effectiveRange: nil) as? URL
    }

    public func internalLinkAt(point: NSPoint) -> String? {
        guard let layout = layout else { return nil }
        let line = lineAt(point: point)
        guard line >= 0 else { return nil }
        let l = layout.lines[line]
        guard l.frame.minX <= point.x && l.frame.maxX >= point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: point)
        let pos = min(displayIndex, attributedString.length - 1)
        return attributedString.attribute(.link, at: pos, effectiveRange: nil) as? String
    }

    public func offsetAt(index: Int) -> CGFloat {
        let layout = emptyLayout ?? self.layout
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        guard let line = lineAt(index: displayIndex) else { return 0 }
        let layoutLine = layout!.lines[line]
        let positionInLine = displayIndex
        let result = layoutLine.offsetFor(index: positionInLine)
        return CGFloat(result)
    }

    public func offsetAndFrameAt(index: Int) -> (CGFloat, NSRect) {
        let displayIndex = displayIndexFor(sourceIndex: index)

        guard layout != nil,
              !layout!.lines.isEmpty,
              let line = lineAt(index: displayIndex) else { return (0, NSRect()) }

        let layoutLine = layout!.lines[line]
        let positionInLine = displayIndex
        let result = layoutLine.offsetFor(index: positionInLine)

        return (CGFloat(result), layoutLine.frame)
    }

    public func positionAbove(_ position: Int) -> Int {
        guard let l = lineAt(index: position), l > 0 else { return 0 }
        let offset = offsetAt(index: position)
        let indexAbove = layout!.lines[l - 1].stringIndexFor(position: NSPoint(x: offset, y: 0))
        return sourceIndexFor(displayIndex: indexAbove)
    }

    public func positionBelow(_ position: Int) -> Int {
        guard let l = lineAt(index: position), l < layout!.lines.count - 1 else { return text.count }
        let offset = offsetAt(index: position)
        let indexBelow = layout!.lines[l + 1].stringIndexFor(position: NSPoint(x: offset, y: 0))
        return sourceIndexFor(displayIndex: indexBelow)
    }

    public func isOnFirstLine(_ position: Int) -> Bool {
        guard let l = lineAt(index: position) else { return false }
        return l == 0
    }

    public func isOnLastLine(_ position: Int) -> Bool {
        guard let layout = layout else { return true }
        guard layout.lines.count > 1 else { return true }
        guard let l = lineAt(index: position) else { return false }
        return l == layout.lines.count - 1
    }

    public func rectAt(_ position: Int) -> NSRect {
        updateRendering()
        guard let l = lineAt(index: position) else { return NSRect() }
        let x1 = offsetAt(index: position)
        return NSRect(x: x1, y: CGFloat(l) * fontSize, width: 1.5, height: fontSize )
    }

    public func indexOnLastLine(atOffset x: CGFloat) -> Int {
        guard let lines = layout?.lines else { return 0 }
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
        guard let lines = layout?.lines else { return 0 }
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
        if frameAnimation != nil {
            context.setFillColor(NSColor.blue.cgColor.copy(alpha: 0.2)!)
            context.fill(NSRect(origin: NSPoint(), size: contentsFrame.size))
        }
        // draw debug:
        guard debug, hover || isEditing else { return }

        let c = isEditing ? NSColor.red.cgColor : NSColor.gray.cgColor
        context.setStrokeColor(c)
        let bounds = NSRect(origin: CGPoint(), size: currentFrameInDocument.size)
        context.stroke(bounds)

        context.setFillColor(c.copy(alpha: 0.2)!)
        context.fill(contentsFrame)
    }

    private func buildAttributedString(for beamText: BeamText) -> NSAttributedString {
        let str = beamText.buildAttributedString(fontSize: fontSize, cursorPosition: cursorPosition, elementKind: elementKind)
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
        return buildAttributedString(for: elementText)
    }

    internal func actionLayerMousePosition(from mouseInfo: MouseInfo) -> NSPoint {
        return NSPoint(x: indent + mouseInfo.position.x, y: mouseInfo.position.y)
    }

    private func showHoveredActionLayers(_ hovered: Bool) {
        guard !elementText.isEmpty else { return }

        actionLayerIsHovered = hovered
        icon = icon?.fill(color: hovered ? .editorSearchHover : .editorSearchNormal)
        actionImageLayer.contents = icon
        actionImageLayer.opacity = 1
        actionImageLayer.setAffineTransform(hovered ? CGAffineTransform(translationX: 1, y: 0) : CGAffineTransform.identity)

        actionTextLayer.opacity = hovered ? 1 : 0
        actionTextLayer.foregroundColor = hovered ? NSColor.editorSearchHover.cgColor : NSColor.editorSearchNormal.cgColor
        actionTextLayer.setAffineTransform(hovered ? CGAffineTransform(translationX: 11, y: 0) : CGAffineTransform.identity)
    }

    private func resetActionLayers() {
        icon = icon?.fill(color: .editorSearchNormal)
        actionLayerIsHovered = false
        actionImageLayer.contents = icon
        actionImageLayer.opacity = 0
        actionTextLayer.opacity = 0
        actionImageLayer.setAffineTransform(CGAffineTransform.identity)
        actionTextLayer.setAffineTransform(CGAffineTransform.identity)
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
        print("\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers - element id: \(element.id) [\(elementText.text)]")
        for c in children {
            c.dumpWidgetTree(level + 1)
        }
    }

}
