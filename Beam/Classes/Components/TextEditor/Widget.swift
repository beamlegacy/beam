//
//  Widget.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/12/2020.
//

import Foundation
import Cocoa
import Combine

// swiftlint:disable type_body_length
// swiftlint:disable file_length
public class Widget: NSAccessibilityElement, CALayerDelegate, MouseHandler {
    let layer: CALayer
    var debug = false
    var currentFrameInDocument = NSRect()

    var isEmpty: Bool { children.isEmpty }
    var selected: Bool = false {
        didSet {
            layer.backgroundColor = selected ? NSColor(white: 0.5, alpha: 0.1).cgColor : NSColor(white: 1, alpha: 0).cgColor
            invalidate()
        }
    }

    var contentsScale = CGFloat(2) {
        didSet {
            layer.contentsScale = contentsScale

            for layer in layers.values {
                layer.layer.contentsScale = contentsScale
            }

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
//            layer.backgroundColor = hover ? NSColor.red.withAlphaComponent(0.3).cgColor : nil
        }
    }
    var cursor: NSCursor?

    internal var children: [Widget] = [] {
        didSet {
            updateChildren(oldValue)
            invalidateLayout()
        }
    }

    func updateChildren(_ oldValue: [Widget]? = nil) {
        // First remove all old layers from the editor:
        if let oldValue = oldValue {
            var set = Set<Widget>(oldValue)

            for c in children {
                set.remove(c)
            }

            for c in set {
                c.removeFromSuperlayer(recursive: true)
            }
        }

        // Then make sure everything is correctly on screen
        for c in children {
            c.parent = self
            c.availableWidth = availableWidth - childInset
            c.contentsScale = contentsScale
            editor.layer?.addSublayer(c.layer)
            for l in c.layers where l.value.layer.superlayer == nil {
                editor.layer?.addSublayer(l.value.layer)
            }
        }
    }

    var enabled: Bool { editor.enabled }
    var scope = Set<AnyCancellable>()

    var contentsFrame = NSRect() // The rectangle of our text excluding children
    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: contentsFrame.width, height: contentsFrame.height)
    }

    var availableWidth: CGFloat = 1 {
        didSet {
            updateChildren()
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

    weak var parent: Widget?

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
        return p.visible && p.open && p.inVisibleBranch
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
    public private(set) var needLayout = true

    public static func == (lhs: Widget, rhs: Widget) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer

    init(editor: BeamTextEdit) {
        self.editor = editor
        layer = CALayer()
        super.init()
        configureLayer()

        setAccessibilityIdentifier(String(describing: Self.self))
        setAccessibilityElement(true)
        setAccessibilityLabel("Widget")
        setAccessibilityRole(.none)
        setAccessibilityParent(editor)
    }

    deinit {
        removeFromSuperlayer(recursive: true)
    }

    func removeFromSuperlayer(recursive: Bool) {
        layer.removeFromSuperlayer()

        // handle sublayers:
        for l in layers where l.value.layer.superlayer == editor.layer {
            l.value.layer.removeFromSuperlayer()
        }

        if recursive {
            for c in children {
                c.removeFromSuperlayer(recursive: recursive)
            }
        }
    }

    func addLayerTo(layer: CALayer, recursive: Bool) {
        layer.addSublayer(self.layer)
        layer.contentsScale = contentsScale
        for subLayer in layers.values where subLayer.layer.superlayer != layer {
            layer.addSublayer(subLayer.layer)
        }

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
            context.saveGState(); do { context.restoreGState() }
        }
        context.restoreGState()
    }

    func updateSubLayersLayout() { }

    func setLayout(_ frame: NSRect) {
        self.frame = frame
        needLayout = false
        layer.bounds = contentsFrame
        layer.position = frameInDocument.origin
        updateSubLayersLayout()

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
        layer.backgroundColor = selected ? NSColor(white: 0.5, alpha: 0.1).cgColor : NSColor(white: 1, alpha: 0).cgColor
        layer.delegate = self
        layer.name = mainLayerName
    }

    var mainLayerName: String {
        String(describing: self)
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

    var open: Bool = true {
        didSet {
            if let chevron = self.layers["disclosure"] as? ChevronButton {
                chevron.open = open
            }
            updateChildrenVisibility(visible && open)
            invalidateLayout()
        }
    }

    // TODO: Refactor this in two methods
    func updateChildrenVisibility(_ isVisible: Bool) {
        for c in children {
            c.visible = isVisible
            c.updateChildrenVisibility(isVisible && c.open)
            invalidateLayout()
        }
    }

    func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            contentsFrame = NSRect()

            if selfVisible {
                // do something
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
        children.append(child)
        invalidateLayout()
    }

    func removeChild(_ child: Widget) {
        children.removeAll { w -> Bool in
            w === child
        }
        child.removeFromSuperlayer(recursive: true)

        invalidateLayout()
    }

    func clear() {
        let c = children
        for child in c {
            removeChild(child)
        }
    }

    func delete() {
        parent?.removeChild(self)
    }

    func insert(node: Widget, after existingNode: Widget) -> Bool {
        guard let pos = children.firstIndex(of: existingNode) else { return false }
        children.insert(node, at: pos + 1)
        invalidateLayout()
        return true
    }

    func insert(node: Widget, at pos: Int) -> Bool {
        children.insert(node, at: pos)
        invalidateLayout()
        return true
    }

    func widgetAt(point: CGPoint) -> Widget? {
        guard visible else { return nil }
        guard 0 <= point.y, point.y < frame.height else { return nil }

        if contentsFrame.minY <= point.y, point.y < contentsFrame.maxY {
            return self
        }

        for c in children {
            let p = CGPoint(x: point.x - c.frame.origin.x, y: point.y - c.frame.origin.y)
            if let res = c.widgetAt(point: p) {
                return res
            }
        }

        return nil
    }

    internal var layers: [String: Layer] = [:]
    func addLayer(_ layer: Layer, origin: CGPoint? = nil, global: Bool = false) {
        layer.frame = CGRect(origin: origin ?? layer.frame.origin, size: layer.frame.size)

        if global {
            editor.layer?.addSublayer(layer.layer)
        } else if layer.layer.superlayer == nil {
            self.layer.addSublayer(layer.layer)

            layer.setAccessibilityParent(self)
//            layer.setAccessibilityFrameInParentSpace(layer.frame)
        }

        layers[layer.name] = layer
    }

    func removeLayer(_ layer: Layer) {
        removeLayer(layer.name)
    }

    func removeLayer(_ name: String) {
        layers.removeValue(forKey: name)
    }

    func dispatchHover(_ widgets: Set<Widget>) {
        hover = widgets.contains(self)

        for c in children {
            c.dispatchHover(widgets)
        }
    }

    func dispatchMouseDown(mouseInfo: MouseInfo) -> Widget? {
        guard inVisibleBranch else { return nil }

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            if let d = c.dispatchMouseDown(mouseInfo: i) {
                return d
            }
        }

        clickedLayer = nil
        for layer in layers.values where !layer.layer.isHidden {
            let info = MouseInfo(self, layer, mouseInfo)
            if layer.contains(info.position) {
                if layer.mouseDown(info) {
                    clickedLayer = layer
                    return self
                }
            }
        }

        let rect = NSRect(origin: CGPoint(), size: frame.size)
        guard rect.contains(mouseInfo.position) else {
            return nil
        }

//        print("dispatch down: \(mouseInfo.position)")
        if mouseDown(mouseInfo: mouseInfo) {
            return self
        }

        return contentsFrame.contains(mouseInfo.position) ? self : nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> Widget? {
        guard inVisibleBranch else { return nil }
        guard let focussedNode = root?.focussedWidget else { return nil }

        if focussedNode.handleMouseUp(mouseInfo: mouseInfo) {
            return focussedNode
        }

        return nil
    }

    func handleMouseUp(mouseInfo: MouseInfo) -> Bool {
        defer {
            clickedLayer = nil
        }
        let info = MouseInfo(self, mouseInfo.globalPosition, mouseInfo.event)
//        print("dispatch up: \(info.position) vs \(mouseInfo.position)")

        if let layer = clickedLayer {
            let info = MouseInfo(self, layer, info)
            if layer.mouseUp(info) {
                return true
            }
        }

        return mouseUp(mouseInfo: info)
    }

    func dispatchMouseMoved(mouseInfo: MouseInfo) {
        guard inVisibleBranch else { return }
        _ = handleMouseMoved(mouseInfo: mouseInfo)

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            c.dispatchMouseMoved(mouseInfo: i)
        }
    }

    func getWidgetsAt(_ position: NSPoint, _ globalPosition: NSPoint) -> [MouseHandler] {
        guard inVisibleBranch else { return [] }
        var handlers: [MouseHandler] = layer.frame.contains(globalPosition) ? [self] : []

        for c in children {
            var p = position
            p.x -= c.frame.origin.x
            p.y -= c.frame.origin.y

            handlers += c.getWidgetsAt(p, globalPosition)
        }

        for layer in layers.values where !layer.layer.isHidden {
            let p = MouseInfo.convert(globalPosition: globalPosition, self, layer)
            if layer.contains(p) {
                handlers.append(layer)
            }
        }

        return handlers
    }

    func getWidgetsBetween(_ start: NSPoint, _ end: NSPoint) -> [Widget] {
        guard inVisibleBranch else { return [] }
        var widgets: [Widget] = []
        if layer.frame.minY > start.y && layer.frame.minY < end.y {
            widgets.append(self)
        } else if layer.frame.maxY < start.y && layer.frame.maxY > end.y {
            widgets.append(self)
        }

        for c in children {
            var p = start
            p.x -= c.frame.origin.x
            p.y -= c.frame.origin.y

            widgets += c.getWidgetsBetween(start, end)
        }
        return widgets
    }

    func dispatchMouseDragged(mouseInfo: MouseInfo) -> Widget? {
        guard inVisibleBranch else { return nil }
        guard let focussedNode = root?.focussedWidget else { return nil }

        if focussedNode.handleMouseDragged(mouseInfo: mouseInfo) {
            return focussedNode
        }

        return nil
    }

    func focus() {
    }

    func unfocus() {
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
        dragMode = .none
        return false
    }

    func handleMouseMoved(mouseInfo: MouseInfo) -> Bool {
        var res = false
        for layer in layers.values where !layer.layer.isHidden {
            let info = MouseInfo(self, layer, mouseInfo)
            if layer.handleMouseMoved(info) {
                res = res || true
            }
        }

        return res || mouseMoved(mouseInfo: mouseInfo)
    }

    func mouseMoved(mouseInfo: MouseInfo) -> Bool {
        return false
    }

    weak var clickedLayer: Layer?
    func handleMouseDragged(mouseInfo: MouseInfo) -> Bool {
        let info = MouseInfo(self, mouseInfo.globalPosition, mouseInfo.event)
//        print("handle dragged: \(info.position) vs \(mouseInfo.position)")

        var res = false
        if let layer = clickedLayer {
            let info = MouseInfo(self, layer, mouseInfo)
            res = layer.mouseDragged(info)
        }

        return res || mouseDragged(mouseInfo: info)
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

    var areAllChildrenSelected: Bool {
        for child in children {
            if !child.selected || !child.areAllChildrenSelected {
                return false
            }
        }
        return true
    }

    func dumpWidgetTree(_ level: Int = 0) {
        let tabs = String.tabs(level)
        print("\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers")
        for c in children {
            c.dumpWidgetTree(level + 1)
        }
    }

    func nodeFor(_ element: BeamElement) -> TextNode {
        guard let parent = parent else { return editor.nodeFor(element) }
        return parent.nodeFor(element)
    }

    func removeNode(_ node: TextNode) {
        guard let parent = parent else { editor.removeNode(node); return }
        parent.removeNode(node)
    }

    // Accessibility:
    public override func accessibilityChildren() -> [Any]? {
        return layers.values.compactMap({ layer -> Layer? in
            layer.layer.isHidden ? nil : layer
        })
    }

    public override func accessibilityFrameInParentSpace() -> NSRect {
        // We are flipped, but the accessibility framework ignores it so we need to change that by hand:
        let parentRect = editor.frame
        let rect = NSRect(origin: layer.position, size: layer.bounds.size)
        let actualY = parentRect.height - rect.maxY
        let correctedRect = NSRect(origin: CGPoint(x: rect.minX, y: actualY), size: rect.size)
//        print("\(Self.self) actualY = \(actualY) - rect \(rect) - parentRect \(parentRect) -> \(correctedRect)")
        return correctedRect
    }

    var allVisibleChildren: [Widget] {
//        guard inVisibleBranch else { return [] }
        guard visible else { return [] }
        var widgets: [Widget] = []

        for child in children where child.visible {
            widgets.append(child)
            widgets += child.allVisibleChildren
        }

        return widgets
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
