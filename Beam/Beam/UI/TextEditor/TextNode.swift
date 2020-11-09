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

// swiftlint:disable:next type_body_length
public class TextNode: Equatable {
    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    var text: String = "" {
        didSet {
            guard oldValue != text else { return }
            bullet?.content = text
            CoreDataManager.shared.save()
            invalidateTextRendering()
        }
    }

    var placeholder: String = "" {
        didSet {
            guard oldValue != text else { return }
            invalidateTextRendering()
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
        _language = NLLanguageRecognizer.dominantLanguage(for: root.fullStrippedText)
        return _language
    }

    var bullet: Bullet?
    var isReference = false
    var isReferenceBranch: Bool {
        return isReference ? true : (parent?.isReferenceBranch ?? false)
    }
    var open = true { didSet { invalidateLayout() } }
    var selfVisible = true { didSet { invalidateLayout() } }
    var hover: Bool = false {
        didSet {
            invalidate()
        }
    }
    var _attributedString: NSAttributedString?
    var attributedString: NSAttributedString {
        if let s = _attributedString {
            return s
        }

        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        if text.isEmpty && cursorPosition < 0 {
            let attributed = placeholder.attributed

            attributed.setAttributes([.font: visitor.font(for: visitor.context), .foregroundColor: disabledColor], range: attributed.wholeRange)
            _attributedString = attributed
            return attributed
        }
        let parser = Parser(inputString: text)
        let AST = parser.parseAST()

//        print("AST:\n\(AST.treeString)")

        if root.node === self && editor?.hasFocus ?? true {
            visitor.cursorPosition = cursorPosition
        }
        let str = visitor.visit(AST)

        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = 1.56

        str.addAttribute(.paragraphStyle, value: paragraphStyle, range: str.wholeRange)
        _attributedString = str
        return str
    }
    var debug = false

    var layout: TextFrame?
    public private(set) var children: [TextNode] = []

    func addChild(_ child: TextNode) {
        if let p = child.parent, p !== self {
            p.removeChild(child)
        }
        children.append(child)
        child.parent = self
        invalidateLayout()
    }

    func removeChild(_ child: TextNode) {
        children.removeAll { node -> Bool in
            node === child
        }
        child.parent = nil
        invalidateLayout()
    }

    func delete() {
        bullet?.delete(coreDataManager.mainContext)
        parent?.removeChild(self)
    }

    func insert(node: TextNode, after existingNode: TextNode) -> Bool {
        guard let pos = existingNode.indexInParent else { return false }
        node.parent?.removeChild(node)
        children.insert(node, at: pos + 1)
        node.parent = self
        invalidateLayout()
        return true
    }

    func setChild(_ node: TextNode, at index: Int) {
        let oldNode = children[index]
        oldNode.parent = nil
        if node.parent !== self {
            node.parent?.removeChild(node)
        }
        children[index] = node
        node.parent = self
        invalidateLayout()
    }

    var config: TextConfig {
        root.config
    }

    var color: NSColor { config.color }
    var disabledColor: NSColor { config.disabledColor }
    var selectionColor: NSColor { config.selectionColor }
    var markedColor: NSColor { config.markedColor }
    var alpha: Float { config.alpha }
    var blendMode: CGBlendMode { config.blendMode }

    var fHeight: Float { config.fHeight }

    var selectedTextRange: Range<Int> { root.selectedTextRange }
    var markedTextRange: Range<Int> { root.markedTextRange }
    var cursorPosition: Int { root.cursorPosition }

    var enabled: Bool { editor?.enabled ?? true }

    var textFrame = NSRect() // The rectangle of our text excluding children
    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: textFrame.width, height: textFrame.height)
    }
    var frame = NSRect() // the total frame including text and children, in the parent reference
    var localFrame: NSRect { // the total frame including text and children, in the local reference
        return NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }

    var disclosureButtonFrame = NSRect(x: 0, y: 0, width: 8, height: 8)
    var disclosurePressed = false
    var showDisclosureButton: Bool {
        depth > 0 && !children.isEmpty
    }

    var showIdentationLine: Bool {
        return depth == 1
    }
    var depth: Int { return allParents.count }

    var indent: CGFloat {
        selfVisible ? 40 : 0
    }

    private var computedIdealSize = NSSize()
    var idealSize: NSSize {
        updateTextRendering()
        return computedIdealSize
    }

    func setLayout(_ frame: NSRect) {
        self.frame = frame
        invalidatedTextRendering = true
        updateTextRendering()

        var pos = NSPoint(x: CGFloat(childInset), y: self.textFrame.height)
        for c in children {
            var childSize = c.idealSize
            childSize.width = frame.width - CGFloat(childInset)
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }

        needLayout = false
    }

    var offsetInDocument: NSPoint { // the position in the global document
        let parentOffset = parent != nil ? parent!.offsetInDocument : NSPoint()
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
        didSet {
            reparent()
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func reparent() {
        guard let p = parent else {
            if !isReferenceBranch, let b = bullet {
                b.parent?.removeFromChildren(b)
                b.note?.removeFromBullets(b)
            }

            for c in children {
                c.reparent()
            }

            invalidateRoot()
            return
        }

        guard let b = bullet else {
            defer {
                for c in children {
                    c.reparent()
                }
            }

            // there is no bullet so we must create one if the parent has one
            if !isReferenceBranch, p.bullet != nil {
                bullet = p.bullet?.note?.createBullet(coreDataManager.mainContext, content: text, createdAt: Date(), afterBullet: previousSibblingNode()?.bullet, parentBullet: p.bullet)
                return
            }

            guard let root = p as? TextRoot else {
                return
            }

            let previousNode: TextNode? = {
                if let i = indexInParent, i != 0 {
                    return p.children[i - 1]
                } else {
                    return nil
                }
            }()
            if !isReferenceBranch {
                let previousBullet = previousNode?.bullet
                bullet = root.note.createBullet(coreDataManager.mainContext, content: text, createdAt: Date(), afterBullet: previousBullet, parentBullet: nil)
            }
            return
        }
        if !isReference {
            guard b.parent !== p.bullet else { return }
            b.parent = p.bullet
        }
    }

    var editor: BeamTextEdit? {
        return root.editor
    }

    private var _root: TextRoot?
    var root: TextRoot {
        if let r = _root {
            return r
        }
        assert(parent != nil)
        let p = parent!
        _root = p.root
        assert(_root != nil)
        return _root!
    }

    private func invalidateRoot() {
        _root = nil

        for c in children {
            c.invalidateRoot()
        }
    }

    init(bullet: Bullet?, recurse: Bool) {
        self.bullet = bullet
        text = bullet?.content.filter({ (char) -> Bool in
            !char.isNewline
        }) ?? "<empty debug>"

//        print("MD: \(bullet.orderIndex) \(node.text)")
        for child in bullet?.sortedChildren() ?? [] {
            addChild(TextNode(bullet: child, recurse: true))
        }

    }

    init(staticText: String) {
        self.text = staticText
//        print("MD: \(bullet.orderIndex) \(node.text)")
        //layout = Font.system(size: 1).draw(string: "", textWidth: 0)
    }

    var readOnly: Bool = false
    var isEditing: Bool { root.node === self }
    var childInset: Float {
        return 40
    }

    private var needLayout = true
    func invalidateLayout() {
        guard !needLayout else { return }
        needLayout = true
        guard let p = parent else { return }
        p.invalidateLayout()
    }

    private var needRedraw = true
    func invalidate() {
        guard !needRedraw else { return }
        needRedraw = true
        guard let p = parent else { return }
        p.invalidate()
    }

    lazy var downTriangle = { NSImage(named: "arrowtriangle.down.fill")!.cgImage }()
    lazy var rightTriangle = { NSImage(named: "arrowtriangle.right.fill")!.cgImage }()

    lazy var symbolFont = NSFont.systemFont(ofSize: 8)

    func symbolFrame(_ string: String) -> TextFrame {
        let symbol = string.attributed
        let attribs: [NSAttributedString.Key: Any] = [
            .font: symbolFont,
            .foregroundColor: NSColor(named: "EditorControlColor")!
        ]
        symbol.setAttributes(attribs, range: symbol.wholeRange)
        return Font.draw(string: symbol, atPosition: NSPoint(), textWidth: 8)
    }

    lazy var disclosureClosedFrame = symbolFrame("􀄧")
    lazy var disclosureOpenFrame = symbolFrame("􀄥")
    lazy var bulletPointFrame = symbolFrame("􀜞")

    func drawDisclosure(at point: NSPoint, in context: CGContext) {
        let symbol = open ? disclosureOpenFrame : disclosureClosedFrame
        context.saveGState()
        context.translateBy(x: point.x + 2, y: point.y - 2)
        symbol.draw(context)
        context.restoreGState()
    }

    func drawBulletPoint(at point: NSPoint, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: point.x + 2, y: point.y - 2)
        bulletPointFrame.draw(context)
        context.restoreGState()
    }

    func drawDebug(in context: CGContext) {
        // draw debug:
        guard debug, hover || isEditing else { return }

        let c = isEditing ? NSColor.red.cgColor : NSColor.gray.cgColor
        context.setStrokeColor(c)
        let bounds = NSRect(origin: CGPoint(), size: frame.size)
        context.stroke(bounds)

        context.setFillColor(c.copy(alpha: 0.2)!)
        context.fill(textFrame)
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

    var firstLineHeight: CGFloat { layout?.lines.first?.bounds.height ?? CGFloat(fHeight) }
    var firstLineBaseline: CGFloat { CGFloat(layout?.lines.first?.typographicBounds.ascent ?? fHeight * 2.0 / 3.0) }

    func drawText(in context: CGContext) {
        // Draw the text:
        context.saveGState()
        if !children.isEmpty {
            if showDisclosureButton {
                context.saveGState()
                if showIdentationLine {
                    context.setFillColor(NSColor(named: "EditorTextRectangleBackgroundColor")!.cgColor)
                    let y = layout!.frame.height
                    let r = NSRect(x: 3, y: y + 3, width: 1, height: frame.height - y - 6)
                    context.fill(r)

                }

                context.restoreGState()
            }
        }

        let offset: NSPoint = {
            return NSPoint(x: 0, y: firstLineBaseline)
        }()
        if showDisclosureButton {
            drawDisclosure(at: NSPoint(x: indent - 42 + offset.x, y: offset.y), in: context)
        }

        drawBulletPoint(at: NSPoint(x: indent - 20 + offset.x, y: offset.y), in: context)

        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: firstLineBaseline)

        layout?.draw(context)
        context.restoreGState()
    }

    public func draw(in context: CGContext, visibleRect: NSRect) {
//        if debug {
//            print("debug \(self)")
//        }

        defer { needRedraw = false }
        updateTextRendering()

        drawDebug(in: context)

        if selfVisible {
            guard localFrame.intersects(visibleRect) else {
    //            print("Skip \(frame) doesn't intersect \(visibleRect)")
                return
            }
    //        print("Draw text \(frame) intersects \(visibleRect)")

            context.saveGState(); defer { context.restoreGState() }

            if localFrame.intersects(visibleRect) {
                drawSelection(in: context)

                drawText(in: context)

                if isEditing {
                    drawCursor(in: context)
                }

            }
        }

        if open {
            drawChildren(in: context, visibleRect: visibleRect)
        }
    }

    func drawChildren(in context: CGContext, visibleRect: NSRect) {
        for c in children {
            drawChild(c, in: context, visibleRect: visibleRect)
        }
    }

    func drawChild(_ child: TextNode, in context: CGContext, visibleRect: NSRect) {
        context.saveGState()
        context.translateBy(x: child.frame.origin.x, y: child.frame.origin.y)

        var vis = visibleRect
        vis.origin.x -= child.frame.origin.x
        vis.origin.y -= child.frame.origin.y
        child.draw(in: context, visibleRect: vis)
        context.restoreGState()
    }

    var invalidatedTextRendering = true
    func invalidateTextRendering() {
        invalidatedTextRendering = true
        _attributedString = nil
        invalidateLayout()
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
            let markRect = NSRect(x: xStart, y: line1.frame.minY, width: xEnd - xStart, height: line1.frame.height)
            context.addRect(markRect)
        } else {
            let markRect1 = NSRect(x: xStart, y: line1.frame.minY, width: frame.width - xStart, height: line1.frame.height )
            context.addRect(markRect1)

            if startLine + 1 != endLine {
                // bloc doesn't end on the line directly below the start line, so be need to joind the start and end lines with a big rectangle
                let markRect2 = NSRect(x: 0, y: line1.frame.minY, width: frame.width, height: line2.imageBounds.minY - line1.imageBounds.maxY)
                context.addRect(markRect2)
            }

            let markRect3 = NSRect(x: 0, y: line2.frame.minY, width: xEnd, height: CGFloat(line2.frame.height) + 1)
            context.addRect(markRect3)
        }

        context.drawPath(using: .fill)
    }

    func drawCursor(in context: CGContext) {
        // Draw fake cursor if the text is empty
        if text.isEmpty {
            guard editor?.hasFocus ?? false, editor?.blinkPhase ?? false else { return }

            let f = AttributedStringVisitor.font()
            let cursorRect = NSRect(x: 0, y: 0, width: 7, height: f.ascender - f.descender)

            context.beginPath()
            context.addRect(cursorRect)
            //let fill = RBFill()
            context.setFillColor(enabled ? color.cgColor : disabledColor.cgColor)

            //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
            context.drawPath(using: .fill)
            return

        }

        guard let editor = editor else { return }
        // Otherwise, draw the cursor at a real position
        guard let cursorLine = lineAt(index: cursorPosition), editor.hasFocus, editor.blinkPhase else { return }

//        var x2 = CGFloat(0)
        let line = layout!.lines[cursorLine]
        let pos = cursorPosition
        let x1 = offsetAt(index: pos)
        let cursorRect = NSRect(x: x1, y: line.frame.minY, width: cursorPosition == text.count ? 7 : 2, height: line.bounds.height)

        context.beginPath()
        context.addRect(cursorRect)
        //let fill = RBFill()
        context.setFillColor(enabled ? color.cgColor : disabledColor.cgColor)

        //list.draw(shape: shape, fill: fill, alpha: 1.0, blendMode: .normal)
        context.drawPath(using: .fill)
    }

    func updateTextRendering() {
        guard frame.width > 0 else { return }
        if invalidatedTextRendering {
            textFrame = NSRect()

            if selfVisible {
                let attrStr = attributedString
                layout = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: frame.width - indent)
                textFrame = layout!.frame

                if attrStr.string.isEmpty {
                    textFrame.size.height = CGFloat(fHeight)
                }
            }
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

    public func lineAt(point: NSPoint) -> Int {
        let y = point.y
        if y >= textFrame.height {
            let v = layout!.lines.count - 1
            return max(v, 0)
        } else if y < 0 {
            return 0
        }

        for (i, l) in layout!.lines.enumerated() where point.y < l.frame.minY + CGFloat(fHeight) {
            return i
        }

        return min(Int(y / CGFloat(fHeight)), layout!.lines.count - 1)
    }

    public func lineAt(index: Int) -> Int? {
        guard index >= 0 else { return nil }
        guard let layout = layout else { return nil }
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
        let _point = NSPoint(x: point.x - textFrame.minX, y: point.y)
        let line = lineAt(point: _point)
        let l = layout!.lines[line]
        let displayIndex = l.stringIndexFor(position: _point)
        let res = sourceIndexFor(displayIndex: displayIndex)
        return res
    }

    public func linkAt(point: NSPoint) -> URL? {
        guard layout != nil, !layout!.lines.isEmpty else { return nil }
        let _point = NSPoint(x: point.x - textFrame.minX, y: point.y)
        let line = lineAt(point: _point)
        guard line >= 0 else { return nil }
        let l = layout!.lines[line]
        guard l.frame.minX < _point.x && l.frame.maxX > _point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: _point)
        let pos = min(displayIndex, attributedString.length - 1)
        return attributedString.attribute(.link, at: pos, effectiveRange: nil) as? URL
    }

    public func internalLinkAt(point: NSPoint) -> String? {
        let _point = NSPoint(x: point.x - textFrame.minX, y: point.y)
        let line = lineAt(point: _point)
        guard line >= 0 else { return nil }
        let l = layout!.lines[line]
        guard l.frame.minX <= _point.x && l.frame.maxX >= _point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: _point)
        let pos = min(displayIndex, attributedString.length - 1)
        return attributedString.attribute(.link, at: pos, effectiveRange: nil) as? String
    }

    func sourceIndexFor(displayIndex: Int) -> Int {
        var range = NSRange()
        let index = displayIndex < attributedString.wholeRange.length ? displayIndex : max(0, displayIndex - 1)
        let attributes = attributedString.attributes(at: index, effectiveRange: &range)
        let ranges = attributes.filter({ $0.key == .sourcePos })
        guard let position = ranges.first else { return 0 }
        guard let number = position.value as? NSNumber else { return 0 }
        return displayIndex - range.location + number.intValue
    }

    func displayIndexFor(sourceIndex: Int) -> Int {
        var found_range = NSRange()
        var found_position = 0
        attributedString.enumerateAttribute(.sourcePos, in: NSRange(location: 0, length: attributedString.length), options: .longestEffectiveRangeNotRequired) { value, range, stop in
            guard let position = value as? NSNumber else { return }
            let p = position.intValue
            if p <= sourceIndex {
                found_range = range
                found_position = p
            }
            if p >= sourceIndex {
                stop.pointee = true
            }
        }

        return found_range.lowerBound + (sourceIndex - found_position)
    }

    public func offsetAt(index: Int) -> CGFloat {
        guard layout != nil, !layout!.lines.isEmpty else { return 0 }
        let displayIndex = displayIndexFor(sourceIndex: index)
        guard let line = lineAt(index: displayIndex) else { return 0 }
        let layoutLine = layout!.lines[line]
        let positionInLine = displayIndex
        let result = layoutLine.offsetFor(index: positionInLine)
        return indent + CGFloat(result)
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
        guard let l = lineAt(index: position) else { return false }
        return l == layout!.lines.count - 1
    }

    public func rectAt(_ position: Int) -> NSRect {
        updateTextRendering()
        guard let l = lineAt(index: position) else { return NSRect() }
        let x1 = offsetAt(index: position)
        return NSRect(x: Float(x1), y: Float(l) * fHeight, width: 1.5, height: fHeight )
    }

    func mouseDown(mouseInfo: MouseInfo) -> Bool {
        if showDisclosureButton && disclosureButtonFrame.contains(mouseInfo.position) {
            print("disclosure pressed (\(open))")
            disclosurePressed = true
            return true
        }
        return false
    }

    func mouseUp(mouseInfo: MouseInfo) -> Bool {
        if disclosurePressed && disclosureButtonFrame.contains(mouseInfo.position) {
            print("disclosure unpressed (\(open))")
            disclosurePressed = false
            open.toggle()
            return true
        }
        return false
    }

    func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        return false
    }

    func mouseDragged(mouseInfo: MouseInfo) -> Bool {
        return false
    }

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

    private func inSubTreeOf(_ node: TextNode) -> Bool {
        if node === self {
            return true
        }
        if let p = parent {
            return p.inSubTreeOf(node)
        }
        return false
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
        let sourceIndex = sourceIndexFor(displayIndex: displayIndex)
        return sourceIndex
    }

    public func indexOnFirstLine(atOffset x: CGFloat) -> Int {
        guard let lines = layout?.lines else { return 0 }
        guard !lines.isEmpty else { return 0 }
        guard let line = lines.first else { return 0 }
        let displayIndex = line.stringIndexFor(position: NSPoint(x: x, y: 0))
        let sourceIndex = sourceIndexFor(displayIndex: displayIndex)
        return sourceIndex
    }

    public func printTree(level: Int = 0) -> String {
        return String.tabs(level)
            + (children.isEmpty ? "- " : (open ? "v - " : "> - "))
            + text + "\n"
            + (open ?
                children.reduce("", { result, child -> String in
                    result + child.printTree(level: level + 1)
                })
                : "")
    }

    var coreDataManager: CoreDataManager {
        return parent!.coreDataManager
    }
}
