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
public class TextNode: NSObject, CALayerDelegate {

    var element: BeamElement { didSet {
        elementScope = element.$text.sink { [unowned self] _ in
            self.invalidateText()
        }
    }}
    var elementScope: Cancellable?
    var layout: TextFrame?
    let layer: CALayer
    var debug = false
    var disclosurePressed = false
    var frameAnimation: FrameAnimation?
    var frameAnimationCancellable = Set<AnyCancellable>()
    var currentFrameInDocument = NSRect()

    var interlineFactor = CGFloat(1.3)
    var interNodeSpacing = CGFloat(4)
    var indent: CGFloat {
        selfVisible ? 25 : 0
    }
    var childInset = Float(23)
    var fontSize = CGFloat(17)
    var isEmpty: Bool { children.isEmpty }

    var contentsScale = CGFloat(2) {
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
            if newValue.isEmpty { resetActionLayers() }
            element.text = newValue
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
            partial + " " + node.fullStrippedText
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

    var open = true {
        didSet {
            invalidateLayout()
            updateVisibility(visible && open)
        }
    }

    var selfVisible = true { didSet { invalidateLayout() } }

    var visible = true {
        didSet {
            layer.isHidden = !visible
        }
    }

    var hover: Bool = false {
        didSet {
            invalidate()
        }
    }

    var _attributedString: NSAttributedString?
    var attributedString: NSAttributedString {
        if _attributedString == nil {
            _attributedString = buildAttributedString()
        }
        return _attributedString!
    }

    internal var children: [TextNode] {
        return element.children.map { childElement -> TextNode in
            editor.nodeFor(childElement)
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
    var cursorPosition: Int { root?.cursorPosition ?? 0 }

    var enabled: Bool { editor.enabled }

    var textFrame = NSRect() // The rectangle of our text excluding children
    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: textFrame.width, height: textFrame.height)
    }

    var availableWidth: CGFloat = 1 {
        didSet {
            if availableWidth != oldValue {
                invalidatedTextRendering = true
                updateRendering()
            }

            for c in children {
                c.availableWidth = availableWidth - CGFloat(childInset)
            }
        }
    }

    var frame = NSRect(x: 0, y: 0, width: 0, height: 0) // the total frame including text and children, in the parent reference
    var localFrame: NSRect { // the total frame including text and children, in the local reference
        return NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }

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

    var depth: Int { return allParents.count }

    var idealSize: NSSize {
        updateRendering()
        return computedIdealSize
    }

    var offsetInDocument: NSPoint { // the position in the global document
        let parentOffset = parent?.offsetInDocument ?? NSPoint()
        let origin = frame.origin
        return NSPoint(x: parentOffset.x + origin.x, y: parentOffset.y + origin.y)
    }

    var offsetInRoot: NSPoint { // the position in the global document
        let parentOffset = parent?.offsetInRoot ?? NSPoint()
        let origin = frame.origin
        return NSPoint(x: parentOffset.x + origin.x, y: parentOffset.y + origin.y)
    }

    var frameInDocument: NSRect {
        let offset = offsetInDocument
        return NSRect(origin: offset, size: frame.size)
    }

    var textFrameInDocument: NSRect {
        let offset = offsetInDocument
        return NSRect(origin: offset, size: textFrame.size)
    }

    var parent: TextNode? {
        guard let p = element.parent else { return nil }
        return editor.nodeFor(p)
    }

    var root: TextRoot? {
        if let r = _root {
            return r
        }
        guard let parent = parent else { return self as? TextRoot }
        _root = parent.root
        return _root
    }

    var readOnly: Bool = false
    var isEditing: Bool { root?.node === self }

    var firstLineHeight: CGFloat { layout?.lines.first?.bounds.height ?? CGFloat(fontSize * interlineFactor) }
    var firstLineBaseline: CGFloat {
        if let firstLine = layout?.lines.first {
            let h = firstLine.typographicBounds.ascent
            return CGFloat(h) + firstLine.frame.minY
        }
        let f = AttributedStringVisitor.font(fontSize)
        return f.ascender
    }

    var isBig: Bool {
        editor.isBig
    }

    var invalidatedTextRendering = true

    let smallCursorWidth = CGFloat(2)
    let bigCursorWidth = CGFloat(7)
    var maxCursorWidth: CGFloat { max(smallCursorWidth, bigCursorWidth) }

    // walking the node tree:
    var inOpenBranch: Bool {
        guard let p = parent else { return true }
        return p.open && p.inOpenBranch
    }

    var allParents: [TextNode] {
        var parents = [TextNode]()
        var node = self
        while let p = node.parent {
            parents.append(p)
            node = p
        }
        return parents
    }

    var isHeader: Bool {
        return text.hasPrefix("# ") || text.hasPrefix("## ")
    }

    var isHigherHeading: Bool {
        return text.hasPrefix("# ")
    }

    var firstVisibleParent: TextNode? {
        var last: TextNode?
        for p in allParents.reversed() {
            if !p.open {
                return last
            }
            last = p
        }
        return nil
    }

    var indexInParent: Int? {
        guard let p = parent else { return nil }
        return p.children.firstIndex { node -> Bool in
            self === node
        }
    }

    public private(set) var editor: BeamTextEdit
    internal var computedIdealSize = NSSize()
    private var _root: TextRoot?
    private var needLayout = true

    private var icon = NSImage(named: "editor-cmdreturn")
    private var actionLayer: CALayer?
    private var actionLayerIsHovered = false
    private let actionImageLayer = CALayer()
    private let actionTextLayer = CATextLayer()
    private let actionLayerFrame = CGRect(x: 30, y: 0, width: 80, height: 20)

    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer

    init(editor: BeamTextEdit, element: BeamElement) {
        self.element = element

        self.editor = editor
        layer = CALayer()
        super.init()
        configureLayer()
        createActionLayer()

        var inInit = true
        elementScope = element.$text.sink { [unowned self] _ in
            guard !inInit else { return }
            self.invalidateText()
        }
        inInit = false
    }

    deinit {
        editor.removeNode(self)
        layer.removeFromSuperlayer()
    }

    // MARK: - Setup UI

    public func draw(_ layer: CALayer, in ctx: CGContext) {
        draw(in: ctx)
    }

    public func draw(in context: CGContext) {
        context.saveGState()
        context.translateBy(x: indent, y: 0)

        //  context.translateBy(x: currentFrameInDocument.origin.x, y: currentFrameInDocument.origin.y)
        //  if debug {
        //      print("debug \(self)")
        //  }

        updateRendering()

        drawDebug(in: context)

        if selfVisible {
            // print("Draw text \(frame))")

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

    func setLayout(_ frame: NSRect) {
        self.frame = frame
        needLayout = false
        layer.bounds = textFrame
        layer.position = frameInDocument.origin

        if self.currentFrameInDocument != frame {
            if isEditing {
                // print("Layout set: \(frame)")
            }
            invalidatedTextRendering = true
            updateRendering()
            invalidate() // invalidate before change
            currentFrameInDocument = frame
            invalidate()  // invalidate after the change
        }

        var pos = NSPoint(x: CGFloat(childInset), y: self.textFrame.height)

        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - CGFloat(childInset)
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }

        updateActionLayer()
    }

    func configureLayer() {
        let newActions = [
                "onOrderIn": NSNull(),
                "onOrderOut": NSNull(),
                "sublayers": NSNull(),
                "contents": NSNull(),
                "bounds": NSNull()
            ]
        layer.actions = newActions
        layer.anchorPoint = CGPoint()
        layer.setNeedsDisplay()
//        layer.backgroundColor = NSColor.red.cgColor.copy(alpha: 0.1)
        layer.backgroundColor = NSColor(white: 1, alpha: 0).cgColor
        let score = element.score
        layer.opacity = 0.3 + (score == 0 ? 1.0 : score) * 0.7
        layer.delegate = self
    }

    func invalidateLayout() {
        invalidate()
        guard !needLayout else { return }
        needLayout = true
        guard let p = parent else { return }
        p.invalidateLayout()
    }

    func invalidate(_ rect: NSRect? = nil) {
        guard let p = parent else { return }
        layer.setNeedsDisplay()
        let offset = NSPoint(x: frame.origin.x + currentFrameInDocument.origin.x - frameInDocument.origin.x,
                             y: frame.origin.y + currentFrameInDocument.origin.y - frameInDocument.origin.y)
        if let r = rect {
            p.invalidate(r.offsetBy(dx: offset.x, dy: offset.y))
        } else {
            let r = NSRect(x: offset.x, y: offset.y, width: currentFrameInDocument.width, height: textFrame.maxY)
            p.invalidate(r)
        }
    }

    func invalidateTextRendering() {
        invalidatedTextRendering = true
        invalidateLayout()
    }

    func invalidateText() {
        if parent == nil {
            _attributedString = nil
            return
        }
        if updateAttributedString() {
            invalidateTextRendering()
        }
    }

    func deepInvalidateTextRendering() {
        invalidateTextRendering()
        for c in children {
            c.deepInvalidateTextRendering()
        }
    }

    func deepInvalidateText() {
        invalidateText()
        for c in children {
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
                    let y = textFrame.height
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
            drawBulletPoint(at: NSPoint(x: offset.x, y: -(firstLineBaseline - 14)), in: context)
        }

        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: firstLineBaseline)

        layout?.draw(context)
        context.restoreGState()
    }

    func drawImage(named: String, at point: NSPoint, in context: CGContext, size: CGRect? = nil) {
        guard var image = NSImage(named: named) else {
            fatalError("Image with name: \(named) can't be found")
        }

        let width = size?.width ?? image.size.width
        let height = size?.height ?? image.size.height
        let rect = CGRect(x: point.x, y: point.y, width: width, height: height)

        image = image.fill(color: NSColor.editorIconColor)

        context.saveGState()
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image.cgImage, in: rect)
        context.restoreGState()
    }

    func drawCursor(in context: CGContext) {
        // Draw fake cursor if the text is empty
        if text.isEmpty || layout!.lines.count == 0 {
            guard editor.hasFocus, editor.blinkPhase else { return }

            let f = AttributedStringVisitor.font(fontSize)
            let cursorRect = NSRect(x: indent, y: 0, width: 7, height: CGFloat(f.ascender - f.descender))

            context.beginPath()
            context.addRect(cursorRect)
            //let fill = RBFill()
            context.setFillColor(enabled ? color.cgColor : disabledColor.cgColor)

            //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
            context.drawPath(using: .fill)
            return
        }

        // Otherwise, draw the cursor at a real position
        guard let cursorLine = lineAt(index: cursorPosition), editor.hasFocus, editor.blinkPhase else { return }

//        var x2 = CGFloat(0)
        let line = layout!.lines[cursorLine]
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

    func updateVisibility(_ isVisible: Bool) {
        for c in children {
            c.visible = isVisible
            c.updateVisibility(open && isVisible)
            invalidateLayout()
        }
    }

    func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedTextRendering {
            textFrame = NSRect()

            if selfVisible {
                let attrStr = attributedString
                let layout = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: (availableWidth - actionLayerFrame.width) - actionLayerFrame.minX)
                self.layout = layout
                textFrame = layout.frame

                if attrStr.string.isEmpty {
                    let f = AttributedStringVisitor.font(fontSize)
                    textFrame.size.height = CGFloat(f.ascender - f.descender) * interlineFactor
                    textFrame.size.width += CGFloat(indent)
                }

                if self as? TextRoot == nil {
                    textFrame.size.height += interNodeSpacing
                }
            }

            textFrame.size.width = availableWidth
            textFrame = textFrame.rounded()

            invalidatedTextRendering = false
        }

        computedIdealSize = textFrame.size
        computedIdealSize.width = frame.width

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
        let actionLayerYPosition = isHeader ? (textFrame.height / 2) - actionLayerFrame.height : 0
        actionLayer?.frame = CGRect(x: (availableWidth - actionLayerFrame.width) + actionLayerFrame.minX, y: actionLayerYPosition, width: actionLayerFrame.width, height: actionLayerFrame.height)
    }

    // MARK: - Methods TextNode

    func addChild(_ child: TextNode) {
        element.addChild(child.element)
        invalidateLayout()
    }

    func removeChild(_ child: TextNode) {
        element.removeChild(child.element)
        invalidateLayout()
    }

    func delete() {
        parent?.removeChild(self)
        editor.removeNode(self)
    }

    func insert(node: TextNode, after existingNode: TextNode) -> Bool {
        element.insert(node.element, after: existingNode.element)
        invalidateLayout()
        return true
    }

    func cancelFrameAnimation() {
        frameAnimation = nil
        frameAnimationCancellable.removeAll()
    }

    func nodeAt(point: CGPoint) -> TextNode? {
        guard 0 <= point.y, point.y < frame.height else { return nil }
        if textFrame.minY <= point.y, point.y < textFrame.maxY {
            return self
        }

        if open {
            for c in children {
                let p = CGPoint(x: point.x - c.frame.origin.x, y: point.y - c.frame.origin.y)
                if let res = c.nodeAt(point: p) {
                    return res
                }
            }
        }
        return nil
    }

    func sourceIndexFor(displayIndex: Int) -> Int {
        return displayIndex
    }

    func displayIndexFor(sourceIndex: Int) -> Int {
        return sourceIndex
    }

    func dispatchMouseDown(mouseInfo: MouseInfo) -> TextNode? {
        guard NSRect(origin: NSPoint(), size: frame.size).contains(mouseInfo.position) else { return nil }

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            if let d = c.dispatchMouseDown(mouseInfo: i) {
                return d
            }
        }

        if mouseDown(mouseInfo: mouseInfo) {
            return self
        }

        return textFrame.contains(mouseInfo.position) ? self : nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> TextNode? {
        guard let focussedNode = root?.node else { return nil }

        var i = mouseInfo
        i.position.x -= focussedNode.offsetInRoot.x
        i.position.y -= focussedNode.offsetInRoot.y
        if focussedNode.mouseUp(mouseInfo: i) {
            return focussedNode
        }

        return nil
    }

    func dispatchMouseDragged(mouseInfo: MouseInfo) -> TextNode? {
        guard let focussedNode = root?.node else { return nil }

        var i = mouseInfo
        i.position.x -= focussedNode.offsetInRoot.x
        i.position.y -= focussedNode.offsetInRoot.y
        if focussedNode.mouseDragged(mouseInfo: i) {
            return focussedNode
        }

        return nil
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

    func fold() {
        if children.isEmpty {
            guard let p = parent else { return }
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

    func focus() {
        guard !text.isEmpty else { return }
        dragMode = .none
        showHoveredActionLayers(false)
    }

    func unfocus() {
        dragMode = .none
        resetActionLayers()
    }

    // MARK: - Mouse Events
    enum DragMode {
        case none
        case select(Int)
    }
    var dragMode = DragMode.none

    func mouseDown(mouseInfo: MouseInfo) -> Bool {
        if showDisclosureButton && disclosureButtonFrame.contains(mouseInfo.position) {
            // print("disclosure pressed (\(open))")
            disclosurePressed = true
            return true
        }

        // Start new query when the action layer is pressed.
        guard let actionLayer = actionLayer else { return false }
        let position = actionLayerMousePosition(from: mouseInfo)

        if isEditing && actionLayerIsHovered && actionLayer.frame.contains(position) {
            editor.onStartQuery(self)
            return true
        }

        if let link = linkAt(point: mouseInfo.position) {
            editor.openURL(link)
            return true
        }
        if let link = internalLinkAt(point: mouseInfo.position) {
            editor.openCard(link)
            return true
        }

        if textFrame.contains(mouseInfo.position) {
            if mouseInfo.event.clickCount == 1 {
                let clickPos = positionAt(point: mouseInfo.position)
                if mouseInfo.event.modifierFlags.contains(.shift) {
                    dragMode = .select(cursorPosition)
                    root?.extendSelection(to: clickPos)
                } else {
                    root?.cursorPosition = clickPos
                    root?.cancelSelection()
                    dragMode = .select(cursorPosition)
                }
            } else {
                root?.doCommand(.selectAll)
            }
        }

        return false
    }

    func mouseUp(mouseInfo: MouseInfo) -> Bool {
        // print("mouseUp (\(mouseInfo))")
        dragMode = .none
        if disclosurePressed && disclosureButtonFrame.contains(mouseInfo.position) {
            // print("disclosure unpressed (\(open))")
            disclosurePressed = false
            open.toggle()

            if !open && root?.node.allParents.contains(self) ?? false {
                root?.focus(node: self)
            }
            return true
        }
        return false
    }

    func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        guard let actionLayer = actionLayer else { return false }

        let position = actionLayerMousePosition(from: mouseInfo)
        let hasTextAndeditable = !text.isEmpty && isEditing

        // Show image & text layers
        if hasTextAndeditable && textFrame.contains(position) && actionLayer.frame.contains(position) {
            showHoveredActionLayers(true)
            return true
        } else if hasTextAndeditable && textFrame.contains(position) {
            showHoveredActionLayers(false)
            return true
        }

        // Reset all layers
        if !textFrame.contains(position) {
            resetActionLayers()
            return true
        }

        return false
    }

    func mouseDragged(mouseInfo: MouseInfo) -> Bool {
        let p = positionAt(point: mouseInfo.position)
        root?.cursorPosition = p

        switch dragMode {
        case .none:
            return false
        case .select(let o):
            root?.selectedTextRange = text.clamp(p < o ? cursorPosition..<o : o..<cursorPosition)
        }
        invalidate()

        return true
    }

    // MARK: - Text & Cursor Position

    public func lineAt(point: NSPoint) -> Int {
        guard let layout = layout else { return 0 }
        let y = point.y
        if y >= textFrame.height {
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

//        if l.isAfterEndOfLine(point) {
//            // find position after all enclosing syntax
//            if let leaf = _ast!.nodeContainingPosition(res),
//               let syntax = leaf.enclosingSyntaxNode {
//                return syntax.end
//            }
//        } else if l.isBeforeStartOfLine(point) {
//            // find position before all enclosing syntax
//            if let leaf = _ast!.nodeContainingPosition(res),
//               let syntax = leaf.enclosingSyntaxNode {
//                return syntax.start
//            }
//        }

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
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        guard let line = lineAt(index: displayIndex) else { return 0 }
        let layoutLine = layout!.lines[line]
        let positionInLine = displayIndex
        let result = layoutLine.offsetFor(index: positionInLine)
        return CGFloat(result)
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

    public func deepestChild() -> TextNode {
        if let n = children.last {
            return n.deepestChild()
        }
        return self
    }

    public func nextNode() -> TextNode? {
        // if we have children, take the first one
        if children.count > 0 {
            return children.first
        }

        // Try to find the next sibbling TextNode:
        if let n = nextSibblingNode() {
            return n
        }

        // Try to find the next TextNode of our parent
        var p = parent
        var n: TextNode?
        while n == nil && p != nil {
            n = p!.nextSibblingNode()
            p = p!.parent
        }

        if n != nil {
            return n
        }

        return nil
    }

    public func previousNode() -> TextNode? {
        if let n = previousSibblingNode() {
            return n.deepestChild()
        }

        if let p = parent {
            return p
        }
        return nil
    }

    public func nextSibblingNode() -> TextNode? {
        if let p = parent {
            let sibblings = p.children
            if let i = sibblings.firstIndex(of: self) {
                if sibblings.count > i + 1 {
                    return sibblings[i + 1]
                }
            }
        }
        return nil
    }

    public func previousSibblingNode() -> TextNode? {
        if let p = parent {
            let sibblings = p.children
            if let i = sibblings.firstIndex(of: self) {
                if i > 0 {
                    return sibblings[i - 1]
                }
            }
        }
        return nil
    }

    // Focus
    public func nextVisible() -> TextNode? {
        var n = nextNode()
        while n != nil && !(n!.inOpenBranch) {
            n = n?.nextNode()
        }

        return n
    }

    public func previousVisible() -> TextNode? {
        var n = previousNode()
        while n != nil && !n!.inOpenBranch {
            n = n!.previousNode()
        }

        return n as? TextRoot == nil ? n : nil
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

    public func printTree(level: Int = 0) -> String {
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

    internal func drawDebug(in context: CGContext) {
        if frameAnimation != nil {
            context.setFillColor(NSColor.blue.cgColor.copy(alpha: 0.2)!)
            context.fill(NSRect(origin: NSPoint(), size: textFrame.size))
        }
        // draw debug:
        guard debug, hover || isEditing else { return }

        let c = isEditing ? NSColor.red.cgColor : NSColor.gray.cgColor
        context.setStrokeColor(c)
        let bounds = NSRect(origin: CGPoint(), size: currentFrameInDocument.size)
        context.stroke(bounds)

        context.setFillColor(c.copy(alpha: 0.2)!)
        context.fill(textFrame)
    }

    private func invalidateRoot() {
        _root = nil

        for c in children {
            c.invalidateRoot()
        }
    }

    private func buildAttributedString() -> NSAttributedString {
//        let config = AttributedStringVisitor.Configuration()
//        let visitor = AttributedStringVisitor(configuration: config)
//        visitor.defaultFontSize = fontSize
//        visitor.context.color = color
//
//        if root != nil && text.isEmpty && cursorPosition < 0 {
//            let attributed = placeholder.attributed
//
//            attributed.setAttributes([.font: visitor.font(for: visitor.context), .foregroundColor: disabledColor], range: attributed.wholeRange)
//            _attributedString = attributed
//            return attributed
//        }
//        let parser = Parser(inputString: text)
//        _ast = parser.parseAST()
//
////        print("AST:\n\(AST.treeString)")
//
//        if root?.node === self && editor.hasFocus {
//            visitor.cursorPosition = selectedTextRange.startIndex
//            visitor.anchorPosition = selectedTextRange.endIndex
//        }
//        let str = visitor.visit(_ast!)

        let str = text.buildAttributedString(fontSize: fontSize, cursorPosition: cursorPosition)
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

    private func inSubTreeOf(_ node: TextNode) -> Bool {
        if node === self {
            return true
        }
        if let p = parent {
            return p.inSubTreeOf(node)
        }
        return false
    }

    private func actionLayerMousePosition(from mouseInfo: MouseInfo) -> NSPoint {
        return NSPoint(x: indent + mouseInfo.position.x, y: mouseInfo.position.y)
    }

    private func showHoveredActionLayers(_ hovered: Bool) {
        guard !text.isEmpty else { return }

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
}
