//
//  Widget.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/12/2020.
//

import Foundation
import Cocoa
import Combine

// swiftlint:disable:next type_body_length
public class Widget: NSObject, CALayerDelegate {
    let layer: CALayer
    var debug = false
    var currentFrameInDocument = NSRect()

    var isEmpty: Bool { children.isEmpty }

    var contentsScale = CGFloat(2) {
        didSet {
            layer.contentsScale = contentsScale
            for c in children {
                c.contentsScale = contentsScale
            }
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

    internal var children: [Widget] = [] {
        didSet {
            for c in children {
                c.parent = self
                c.availableWidth = availableWidth
                c.contentsScale = contentsScale
            }
        }
    }

    var enabled: Bool { editor.enabled }

    var contentsFrame = NSRect() // The rectangle of our text excluding children
    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: contentsFrame.width, height: contentsFrame.height)
    }

    var availableWidth: CGFloat = 1 {
        didSet {
            for c in children {
                c.availableWidth = availableWidth
            }
            if availableWidth != oldValue {
                invalidatedRendering = true
                updateRendering()
            }
        }
    }

    var frame = NSRect(x: 0, y: 0, width: 0, height: 0) // the total frame including text and children, in the parent reference
    var localFrame: NSRect { // the total frame including text and children, in the local reference
        return NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
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
        return NSRect(origin: offset, size: contentsFrame.size)
    }

    var parent: Widget?

    var root: TextRoot? {
        if let r = _root {
            return r
        }
        guard let parent = parent else { return self as? TextRoot }
        _root = parent.root
        return _root
    }

    var isBig: Bool {
        editor.isBig
    }

    var invalidatedRendering = true

    // walking the node tree:
    var inVisibleBranch: Bool {
        guard let p = parent else { return true }
        return p.visible && p.inVisibleBranch
    }

    var allParents: [Widget] {
        var parents = [Widget]()
        var node = self
        while let p = node.parent {
            parents.append(p)
            node = p
        }
        return parents
    }

    var firstVisibleParent: Widget? {
        var last: Widget?
        for p in allParents.reversed() {
            if !p.visible {
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

    public static func == (lhs: Widget, rhs: Widget) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer

    init(editor: BeamTextEdit) {
        self.editor = editor
        layer = CALayer()
        super.init()
        configureLayer()
    }

    deinit {
        layer.removeFromSuperlayer()
    }

    func removeFromSuperlayer(recursive: Bool) {
        layer.removeFromSuperlayer()
        if recursive {
            for c in children {
                c.removeFromSuperlayer(recursive: recursive)
            }
        }
    }

    func addLayerTo(layer: CALayer, recursive: Bool) {
        layer.addSublayer(self.layer)
        if recursive {
            for c in children {
                c.addLayerTo(layer: layer, recursive: recursive)
            }
        }
    }

    // MARK: - Setup UI

    public func draw(_ layer: CALayer, in ctx: CGContext) {
        draw(in: ctx)
    }

    public func draw(in context: CGContext) {
        context.saveGState()

        updateRendering()

        drawDebug(in: context)

        if selfVisible {
            context.saveGState(); defer { context.restoreGState() }
        }
        context.restoreGState()
    }

    func setLayout(_ frame: NSRect) {
        self.frame = frame
        needLayout = false
        layer.bounds = contentsFrame
        layer.position = frameInDocument.origin

        if self.currentFrameInDocument != frame {
            updateLayout()
            invalidatedRendering = true
            updateRendering()
            invalidate() // invalidate before change
            currentFrameInDocument = frame
            invalidate()  // invalidate after the change
        }
        updateChildrenLayout()
    }

    func updateLayout() {
    }

    var childInset: CGFloat = 23

    func updateChildrenLayout() {
        var pos = NSPoint(x: childInset, y: self.contentsFrame.height)

        for c in children {
            let childSize = c.idealSize
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }
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
        layer.backgroundColor = NSColor(white: 1, alpha: 0).cgColor
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
            let r = NSRect(x: offset.x, y: offset.y, width: currentFrameInDocument.width, height: contentsFrame.maxY)
            p.invalidate(r)
        }
    }

    func invalidateRendering() {
        invalidatedRendering = true
        invalidateLayout()
    }

    func deepInvalidateRendering() {
        invalidateRendering()
        for c in children {
            c.deepInvalidateRendering()
        }
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

    func updateVisibility(_ isVisible: Bool) {
        for c in children {
            c.visible = isVisible
            c.updateVisibility(isVisible)
            invalidateLayout()
        }
    }

    func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            contentsFrame = NSRect()

            if selfVisible {
//                let attrStr = attributedString
//                let layout = Font.draw(string: attrStr, atPosition: NSPoint(x: indent, y: 0), textWidth: (availableWidth - actionLayerFrame.width) - actionLayerFrame.minX)
//                self.layout = layout
//                contentsFrame = layout.frame
//
//                if attrStr.string.isEmpty {
//                    let f = AttributedStringVisitor.font(fontSize)
//                    contentsFrame.size.height = CGFloat(f.ascender - f.descender) * interlineFactor
//                    contentsFrame.size.width += CGFloat(indent)
//                }
//
//                if self as? TextRoot == nil {
//                    contentsFrame.size.height += interNodeSpacing
//                }
            }

            contentsFrame.size.width = availableWidth
            contentsFrame = contentsFrame.rounded()

            invalidatedRendering = false
        }

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

//        if open {
            for c in children {
                computedIdealSize.height += c.idealSize.height
            }
//        }
    }

    // MARK: - Methods Widget

    func addChild(_ child: Widget) {
        //addChild(child.element)
        invalidateLayout()
    }

    func removeChild(_ child: Widget) {
        //removeChild(child.element)
        invalidateLayout()
    }

    func delete() {
        parent?.removeChild(self)
//        editor.removeNode(self)
    }

    func insert(node: Widget, after existingNode: Widget) -> Bool {
        guard let pos = children.firstIndex(of: existingNode) else { return false }
        children.insert(node, at: pos + 1)
        invalidateLayout()
        return true
    }

    func nodeAt(point: CGPoint) -> Widget? {
        guard visible else { return nil }
        guard 0 <= point.y, point.y < frame.height else { return nil }
        if contentsFrame.minY <= point.y, point.y < contentsFrame.maxY {
            return self
        }

        for c in children {
            let p = CGPoint(x: point.x - c.frame.origin.x, y: point.y - c.frame.origin.y)
            if let res = c.nodeAt(point: p) {
                return res
            }
        }
        return nil
    }

    func dispatchMouseDown(mouseInfo: MouseInfo) -> Widget? {
        let globalPos = mouseInfo.position
        let rect = NSRect(origin: CGPoint(), size: frame.size)
        guard rect.contains(globalPos) else {
            return nil
        }

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

        return contentsFrame.contains(mouseInfo.position) ? self : nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> Widget? {
        guard let focussedNode = root?.node else { return nil }

        var i = mouseInfo
        i.position.x -= focussedNode.offsetInRoot.x
        i.position.y -= focussedNode.offsetInRoot.y
        if focussedNode.mouseUp(mouseInfo: i) {
            return focussedNode
        }

        return nil
    }

    func dispatchMouseDragged(mouseInfo: MouseInfo) -> Widget? {
        guard let focussedNode = root?.node else { return nil }

        var i = mouseInfo
        i.position.x -= focussedNode.offsetInRoot.x
        i.position.y -= focussedNode.offsetInRoot.y
        if focussedNode.mouseDragged(mouseInfo: i) {
            return focussedNode
        }

        return nil
    }

    func focus() {
        dragMode = .none
    }

    func unfocus() {
        dragMode = .none
    }

    // MARK: - Mouse Events
    enum DragMode {
        case none
        case select(Int)
    }
    var dragMode = DragMode.none

    func mouseDown(mouseInfo: MouseInfo) -> Bool {
        return false
    }

    func mouseUp(mouseInfo: MouseInfo) -> Bool {
        // print("mouseUp (\(mouseInfo))")
        dragMode = .none
        return false
    }

    func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        return false
    }

    func mouseDragged(mouseInfo: MouseInfo) -> Bool {
        return true
    }

    public func deepestChild() -> Widget {
        if let n = children.last {
            return n.deepestChild()
        }
        return self
    }

    public func nextWidget() -> Widget? {
        // if we have children, take the first one
        if children.count > 0 {
            return children.first
        }

        // Try to find the next sibbling Widget:
        if let n = nextSibbling() {
            return n
        }

        // Try to find the next Widget of our parent
        var p = parent
        var n: Widget?
        while n == nil && p != nil {
            n = p!.nextSibbling()
            p = p!.parent
        }

        if n != nil {
            return n
        }

        return nil
    }

    public func previousWidget() -> Widget? {
        if let n = previousSibbling() {
            return n.deepestChild()
        }

        if let p = parent {
            return p
        }
        return nil
    }

    public func nextSibbling() -> Widget? {
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

    public func previousSibbling() -> Widget? {
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
    public func nextVisible() -> Widget? {
        var n = nextWidget()
        while !(n?.inVisibleBranch ?? true) {
            n = n?.nextWidget()
        }

        return n
    }

    public func previousVisible() -> Widget? {
        var n = previousWidget()
        while !(n?.inVisibleBranch ?? true) {
            n = n?.previousWidget()
        }

        return n as? TextRoot == nil ? n : nil
    }

    public func printTree(level: Int = 0) -> String {
        return ""
//        return String.tabs(level)
//            + (children.isEmpty ? "- " : (open ? "v - " : "> - "))
////            + text.text + "\n"
//            + (open ?
//                children.reduce("", { result, child -> String in
//                    result + child.printTree(level: level + 1)
//                })
//                : "")
    }

    // MARK: - Private Methods

    internal func drawDebug(in context: CGContext) {
        // draw debug:
        guard debug, hover else { return }

        let c = NSColor.gray.cgColor
        context.setStrokeColor(c)
        let bounds = NSRect(origin: CGPoint(), size: currentFrameInDocument.size)
        context.stroke(bounds)

        context.setFillColor(c.copy(alpha: 0.2)!)
        context.fill(contentsFrame)
    }

    private func invalidateRoot() {
        _root = nil

        for c in children {
            c.invalidateRoot()
        }
    }

    private func inSubTreeOf(_ node: Widget) -> Bool {
        if node === self {
            return true
        }
        if let p = parent {
            return p.inSubTreeOf(node)
        }
        return false
    }
}
