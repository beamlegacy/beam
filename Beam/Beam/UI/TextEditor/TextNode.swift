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
    public static func == (lhs: TextNode, rhs: TextNode) -> Bool {
        return lhs === rhs
    }

    var text: String = "" {
        didSet {
            guard oldValue != text else { return }
            bullet?.content = text
            CoreDataManager.shared.save()
            invalidateText()
        }
    }

    var placeholder: String = "" {
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
        _language = NLLanguageRecognizer.dominantLanguage(for: root?.fullStrippedText ?? "")
        return _language
    }

    var bullet: Bullet?
    var isReference = false
    var isReferenceBranch: Bool {
        return isReference ? true : (parent?.isReferenceBranch ?? false)
    }
    var open = true { didSet { invalidateLayout()
        for c in children {
            c.visible = open
        }
    } }
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

    let layer: CALayer
    var contentScale: CGFloat = 1 {
        didSet {
            layer.contentsScale = contentScale
            for c in children {
                c.contentScale = contentScale
            }
        }
    }

    private var _ast: Parser.Node?
    private func buildAttributedString() -> NSAttributedString {
        let config = AttributedStringVisitor.Configuration()
        let visitor = AttributedStringVisitor(configuration: config)
        visitor.defaultFontSize = fontSize
        if text.isEmpty && cursorPosition < 0 {
            let attributed = placeholder.attributed

            attributed.setAttributes([.font: visitor.font(for: visitor.context), .foregroundColor: disabledColor], range: attributed.wholeRange)
            _attributedString = attributed
            return attributed
        }
        let parser = Parser(inputString: text)
        _ast = parser.parseAST()

//        print("AST:\n\(AST.treeString)")

        if root?.node === self && editor?.hasFocus ?? true {
            visitor.cursorPosition = selectedTextRange.startIndex
            visitor.anchorPosition = selectedTextRange.endIndex
        }
        let str = visitor.visit(_ast!)

        let paragraphStyle = NSMutableParagraphStyle()
//        paragraphStyle.alignment = .justified
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = 1.56
        paragraphStyle.lineSpacing = 40

        str.addAttribute(.paragraphStyle, value: paragraphStyle, range: str.wholeRange)
        return str
    }

    // update the internal attributed string and return true if it was changed
    @discardableResult private func updateAttributedString() -> Bool {
        let str = buildAttributedString()
        if _attributedString?.isEqual(to: str) ?? false {
            return false
        }

        _attributedString = str
        return true
    }

    var _attributedString: NSAttributedString?
    var attributedString: NSAttributedString {
        if _attributedString == nil {
            _attributedString = buildAttributedString()
        }
        return _attributedString!
    }
    var debug = false

    var layout: TextFrame?
    public private(set) var children: [TextNode] = []

    func addChild(_ child: TextNode) {
        if let p = child.parent, p !== self {
            p.removeChild(child)
        }
        children.append(child)
        fakeLayoutChild(child)
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
        fakeLayoutChild(node)
        node.parent = self
        invalidateLayout()
        return true
    }

    func fakeLayoutChild(_ node: TextNode) {
        // force layout on the child to have a valid initial flow
        if node.parent == nil && node.frame.width == 0 && node.frame.height == 0 {
            node.frame.size.width = 1
        }
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
        root!.config
    }

    var color: NSColor { config.color }
    var disabledColor: NSColor { config.disabledColor }
    var selectionColor: NSColor { config.selectionColor }
    var markedColor: NSColor { config.markedColor }
    var alpha: Float { config.alpha }
    var blendMode: CGBlendMode { config.blendMode }

    var selectedTextRange: Range<Int> { root!.selectedTextRange }
    var markedTextRange: Range<Int> { root!.markedTextRange }
    var cursorPosition: Int { root!.cursorPosition }

    var enabled: Bool { editor?.enabled ?? true }

    var textFrame = NSRect() // The rectangle of our text excluding children
    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: textFrame.width, height: textFrame.height)
    }
    var frame = NSRect() // the total frame including text and children, in the parent reference
    var localFrame: NSRect { // the total frame including text and children, in the local reference
        return NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }

    var disclosureButtonFrame: NSRect {
        let r = (open ? disclosureOpenFrame : disclosureClosedFrame).frame
        return r.offsetBy(dx: 0, dy: r.height).insetBy(dx: -4, dy: -4)
    }
    var disclosurePressed = false
    var showDisclosureButton: Bool {
        depth > 0 && !children.isEmpty
    }

    var showIdentationLine: Bool {
        return depth == 1
    }
    var depth: Int { return allParents.count }

    var indent: CGFloat {
        selfVisible ? 15 : 0
    }

    private var computedIdealSize = NSSize()
    var idealSize: NSSize {
        updateTextRendering()
        return computedIdealSize
    }

    var frameAnimation: FrameAnimation?
    var frameAnimationCancellable = Set<AnyCancellable>()
    func cancelFrameAnimation() {
        frameAnimation = nil
        frameAnimationCancellable.removeAll()
    }

    func setLayout(_ frame: NSRect) {
        self.frame = frame
        needLayout = false
        layer.bounds = textFrame
        layer.position = frameInDocument.origin

        layout(frame)
    }

//    public func layoutSublayers(of layer: CALayer) {
//        for c in children {
//            c.layer.bounds = CGRect(origin: CGPoint(), size: c.frame.size)
//            c.layer.position = c.frame.origin
//        }
//    }

    func layout(_ frame: NSRect) {
        if self.currentFrameInDocument != frame {
            if isEditing {
//                print("Layout set: \(frame)")
            }
            invalidatedTextRendering = true
            updateTextRendering()
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

    var currentFrameInDocument = NSRect()

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
    func reparent() {
        defer {
            for c in children {
                c.reparent()
            }
        }

        guard let p = parent else {
            if !isReferenceBranch, let b = bullet {
                b.parent?.removeFromChildren(b)
                b.note?.removeFromBullets(b)
            }

            invalidateRoot()
            return
        }

        layer.contentsScale = p.layer.contentsScale
        if let superLayer = p.editor?.layer {
            if layer.superlayer != superLayer {
                superLayer.addSublayer(layer)
            }
        }
        guard let b = bullet else {
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
        return root?.editor
    }

    private var _root: TextRoot?
    var root: TextRoot? {
        if let r = _root {
            return r
        }
        guard let parent = parent else { return nil }
        _root = parent.root
        return _root
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

        layer = CALayer()
        super.init()
        configureLayer()

//        print("MD: \(bullet.orderIndex) \(node.text)")
        for child in bullet?.sortedChildren() ?? [] {
            addChild(TextNode(bullet: child, recurse: true))
        }

    }

    init(staticText: String) {
        self.text = staticText
//        print("MD: \(bullet.orderIndex) \(node.text)")
        //layout = Font.system(size: 1).draw(string: "", textWidth: 0)

        layer = CALayer()
//        layer.backgroundColor = NSColor.red.cgColor.copy(alpha: 0.1)
        super.init()
        configureLayer()
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
        layer.opacity = 1.0
        layer.delegate = self
    }

    var readOnly: Bool = false
    var isEditing: Bool { root?.node === self }
    var childInset = Float(20)

    private var needLayout = true
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

    var fontSize: CGFloat { isBig ? 16 : 14 }

    static func symbolFont(_ size: CGFloat) -> NSFont {
        return NSFont.systemFont(ofSize: size)
    }

    static func symbolFrame(_ size: CGFloat, _ string: String) -> TextFrame {
        let symbol = string.attributed
        let attribs: [NSAttributedString.Key: Any] = [
            .font: symbolFont(size),
            .foregroundColor: NSColor(named: "EditorControlColor")!
        ]
        symbol.setAttributes(attribs, range: symbol.wholeRange)
        return Font.draw(string: symbol, atPosition: NSPoint(x: 2, y: -2), textWidth: 8)
    }

    static var disclosureClosedFrameSmall = symbolFrame(7, "􀄧")
    static var disclosureOpenFrameSmall = symbolFrame(7, "􀄥")
    static var bulletPointFrameSmall = symbolFrame(7, "􀜞")
    static var disclosureClosedFrameBig = symbolFrame(7, "􀄧")
    static var disclosureOpenFrameBig = symbolFrame(7, "􀄥")
    static var bulletPointFrameBig = symbolFrame(7, "􀜞")

    var isBig: Bool {
        editor?.isBig ?? false
    }

    var disclosureClosedFrame: TextFrame { isBig ? Self.disclosureClosedFrameBig : Self.disclosureClosedFrameSmall }
    var disclosureOpenFrame: TextFrame { isBig ? Self.disclosureOpenFrameBig : Self.disclosureOpenFrameSmall }
    var bulletPointFrame: TextFrame { isBig ? Self.bulletPointFrameBig : Self.bulletPointFrameSmall }

    func drawDisclosure(at point: NSPoint, in context: CGContext) {
//        context.setFillColor(gray: 0.5, alpha: 0.5)
//        context.fill(disclosureButtonFrame)
        let symbol = open ? disclosureOpenFrame : disclosureClosedFrame
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        symbol.draw(context)
        context.restoreGState()

    }

    func drawBulletPoint(at point: NSPoint, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        bulletPointFrame.draw(context)
        context.restoreGState()
    }

    func drawDebug(in context: CGContext) {
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

    var interlineFactor = CGFloat(1.56)
    var firstLineHeight: CGFloat { layout?.lines.first?.bounds.height ?? CGFloat(fontSize * interlineFactor) }
    var firstLineBaseline: CGFloat {
        if let h = layout?.lines.first?.typographicBounds.ascent {
            return CGFloat(h)
        }
        let f = AttributedStringVisitor.font(fontSize)
        return f.ascender
    }

    func drawText(in context: CGContext) {
        // Draw the text:
        context.saveGState()
        if !children.isEmpty {
            if showDisclosureButton {
                context.saveGState()
                if showIdentationLine {
                    context.setFillColor(NSColor(named: "EditorTextRectangleBackgroundColor")!.cgColor)
                    let y = textFrame.height
                    let r = NSRect(x: 5, y: y + 3, width: 1, height: currentFrameInDocument.height - y - 6)
                    context.fill(r)

                }

                context.restoreGState()
            }
        }

        let offset = NSPoint(x: 0, y: firstLineBaseline)
        if showDisclosureButton {
            drawDisclosure(at: NSPoint(x: offset.x, y: offset.y), in: context)
        } else {
            drawBulletPoint(at: NSPoint(x: offset.x, y: offset.y), in: context)
        }

        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: firstLineBaseline)

        layout?.draw(context)
        context.restoreGState()
    }

    public func draw(_ layer: CALayer, in ctx: CGContext) {
        draw(in: ctx)
    }

    public func draw(in context: CGContext) {
        context.saveGState()
        context.translateBy(x: indent, y: 0)

//        context.translateBy(x: currentFrameInDocument.origin.x, y: currentFrameInDocument.origin.y)
//        if debug {
//            print("debug \(self)")
//        }

        updateTextRendering()

        drawDebug(in: context)

        if selfVisible {
    //        print("Draw text \(frame))")

            context.saveGState(); defer { context.restoreGState() }

            drawSelection(in: context)

            drawText(in: context)

            if isEditing {
                drawCursor(in: context)
            }
        }
        context.restoreGState()
    }

    var invalidatedTextRendering = true
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

    let smallCursorWidth = CGFloat(2)
    let bigCursorWidth = CGFloat(7)
    var maxCursorWidth: CGFloat { max(smallCursorWidth, bigCursorWidth) }

    func drawCursor(in context: CGContext) {
        // Draw fake cursor if the text is empty
        if text.isEmpty {
            guard editor?.hasFocus ?? false, editor?.blinkPhase ?? false else { return }

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

        guard let editor = editor else { return }
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

    func updateTextRendering() {
        guard frame.width > 0 else { return }
        if invalidatedTextRendering {
            textFrame = NSRect()

            if selfVisible {
                let attrStr = attributedString
                layout = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: frame.width - indent, interlineFactor: interlineFactor)
                textFrame = layout!.frame

                if attrStr.string.isEmpty {
                    let f = AttributedStringVisitor.font(fontSize)
                    textFrame.size.height = CGFloat(f.ascender - f.descender) * interlineFactor
                }
            }
            textFrame.size.width += maxCursorWidth
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

        for (i, l) in layout!.lines.enumerated() where point.y < l.frame.minY + CGFloat(fontSize) {
            return i
        }

        return min(Int(y / CGFloat(fontSize)), layout!.lines.count - 1)
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

        if l.isAfterEndOfLine(point) {
            // find position after all enclosing syntax
            if let leaf = _ast!.nodeContainingPosition(res),
               let syntax = leaf.enclosingSyntaxNode {
                return syntax.end
            }
        } else if l.isBeforeStartOfLine(point) {
            // find position before all enclosing syntax
            if let leaf = _ast!.nodeContainingPosition(res),
               let syntax = leaf.enclosingSyntaxNode {
                return syntax.start
            }
        }

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
        let line = lineAt(point: point)
        guard line >= 0 else { return nil }
        let l = layout!.lines[line]
        guard l.frame.minX <= point.x && l.frame.maxX >= point.x else { return nil } // don't find links outside the line
        let displayIndex = l.stringIndexFor(position: point)
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
        updateTextRendering()
        guard let l = lineAt(index: position) else { return NSRect() }
        let x1 = offsetAt(index: position)
        return NSRect(x: x1, y: CGFloat(l) * fontSize, width: 1.5, height: fontSize )
    }

    func dispatchMouseDown(mouseInfo: MouseInfo) -> TextNode? {
        guard NSRect(origin: NSPoint(), size: frame.size).contains(mouseInfo.position) else { return nil }
        if mouseDown(mouseInfo: mouseInfo) {
            return self
        }

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            if let d = c.dispatchMouseDown(mouseInfo: i) {
                return d
            }
        }

        return nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> TextNode? {
        guard NSRect(origin: NSPoint(), size: frame.size).contains(mouseInfo.position) else { return nil }
        if mouseUp(mouseInfo: mouseInfo) {
            return self
        }

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            if let d = c.dispatchMouseUp(mouseInfo: i) {
                return d
            }
        }

        return nil
    }

    func mouseDown(mouseInfo: MouseInfo) -> Bool {
//        print("mouseDown (\(mouseInfo))")
        if showDisclosureButton && disclosureButtonFrame.contains(mouseInfo.position) {
//            print("disclosure pressed (\(open))")
            disclosurePressed = true
            return true
        }
        return false
    }

    func mouseUp(mouseInfo: MouseInfo) -> Bool {
//        print("mouseUp (\(mouseInfo))")
        if disclosurePressed && disclosureButtonFrame.contains(mouseInfo.position) {
//            print("disclosure unpressed (\(open))")
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
}
