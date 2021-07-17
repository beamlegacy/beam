//
//  Widget.swift
//  Beam
//
//  Created by Sebastien Metrot on 23/12/2020.
//

import Foundation
import Cocoa
import Combine
import BeamCore

// swiftlint:disable type_body_length
// swiftlint:disable file_length
public class Widget: NSAccessibilityElement, CALayerDelegate, MouseHandler {
    let layer: CALayer
    let selectionLayer: CALayer
    var debug = false
    var currentFrameInDocument = NSRect()
    var nodeProvider: NodeProvider?
    var isTreeBoundary: Bool { nodeProvider != nil }

    var isEmpty: Bool { children.isEmpty }
    private let selectionInset: CGFloat = 5
    var selectionLayerPosX: CGFloat = 0
    var selectedAlone: Bool = true {
        didSet {
            invalidateLayout()
        }
    }
    var selected: Bool = false {
        didSet {
            selectionLayer.backgroundColor = selected ?
                BeamColor.Generic.textSelection.cgColor :
                NSColor(white: 1, alpha: 0).cgColor
            invalidate()
        }
    }

    var contentsScale = CGFloat(2) {
        didSet {
            layer.contentsScale = contentsScale
            selectionLayer.contentsScale = contentsScale

            for layer in layers.values {
                layer.layer.deepContentsScale = contentsScale
            }

            for c in children {
                c.contentsScale = contentsScale
            }
        }
    }

    var selfVisible = true {
        didSet {
            invalidateLayout()
        }
    }

    var visible = true {
        didSet {
            updateLayersVisibility()
        }
    }

    func updateLayersVisibility() {
        layer.isHidden = !visible || !selfVisible
        for l in layers where l.value.layer.superlayer == editor.layer {
            l.value.layer.isHidden = !visible || !selfVisible
        }
    }

    var hover: Bool = false {
        didSet {
            invalidate()
        }
    }
    var cursor: NSCursor?

    internal var children: [Widget] = [] {
        didSet {
            guard oldValue != children else { return }
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

            // Remove layers for previous children that haven't been reattached to the editor:
            for c in set where c.parent === self || c.parent == nil {
                c.removeFromSuperlayer(recursive: true)
                c.parent = nil
            }
        }

        attachChildrenLayers()
        updateChildrenVisibility(visible && open)
    }

    func attachChildrenLayers() {
        // Then make sure everything is correctly on screen
        for c in children {
            c.parent = self
            c.availableWidth = availableWidth - childInset
            c.contentsScale = contentsScale
            editor.addToMainLayer(c.layer)
            for l in c.layers where l.value.layer.superlayer == nil {
                editor.addToMainLayer(l.value.layer)
            }

            c.attachChildrenLayers()
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
            if availableWidth != oldValue {
                updateChildren()
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

    weak var root: TextRoot? {
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
    private weak var _root: TextRoot?
    public private(set) var needLayout = true

    public static func == (lhs: Widget, rhs: Widget) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer
    init(parent: Widget, nodeProvider: NodeProvider? = nil) {
        self.parent = parent
        self.editor = parent.editor
        self.nodeProvider = nodeProvider
        layer = CALayer()
        layer.isHidden = true
        selectionLayer = CALayer()
        selectionLayer.enableAnimations = false
        super.init()
        self.nodeProvider?.holder = self
        configureLayer()
        configureSelectionLayer()
        availableWidth = parent.availableWidth - parent.childInset

        setAccessibilityIdentifier(String(describing: Self.self))
        setAccessibilityElement(true)
        setAccessibilityLabel("Widget")
        setAccessibilityRole(.none)
        setAccessibilityParent(editor)
    }

    // this version should only be used by TextRoot
    init(editor: BeamTextEdit, nodeProvider: NodeProvider? = nil) {
        self.editor = editor
        self.nodeProvider = nodeProvider
        layer = CALayer()
        layer.isHidden = true
        selectionLayer = CALayer()
        selectionLayer.enableAnimations = false
        super.init()
        self.nodeProvider?.holder = self
        configureLayer()
        configureSelectionLayer()

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
            for c in children where c.parent == self {
                c.removeFromSuperlayer(recursive: recursive)
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

        context.restoreGState()
    }

    func updateSubLayersLayout() { }

    var initialLayout = true
    func setLayout(_ frame: NSRect) {
        self.frame = frame
        needLayout = false

        if initialLayout {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }
        layer.bounds = contentsFrame
        layer.position = frameInDocument.origin
        selectionLayer.bounds = CGRect(x: selectionInset, y: -2.5, width: selectionLayerWidth - selectionInset, height: contentsFrame.height)
        if selectedAlone {
            selectionLayer.position = CGPoint(x: selectionInset, y: -2.5)
            selectionLayer.bounds.size = CGSize(width: selectionLayerWidth - offsetInRoot.x - selectionInset, height: contentsFrame.height)
        } else {
            selectionLayer.position = CGPoint(x: selectionLayerPosX + selectionInset, y: -2.5)
            selectionLayer.bounds.size = CGSize(width: selectionLayerWidth - offsetInRoot.x - selectionLayerPosX - selectionInset, height: contentsFrame.height)
        }
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

        if initialLayout {
            updateLayersVisibility()
            CATransaction.commit()
        }
        initialLayout = false
    }

    func updateLayout() {
    }

    var childInset: CGFloat = 18

    func updateChildrenLayout() {
        var pos = NSPoint(x: childInset, y: self.contentsFrame.height)

        for c in children {
            let childSize = c.idealSize
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)

            pos.y += childSize.height
        }
    }

    var selectionLayerWidth: CGFloat = 570

    private func configureSelectionLayer() {
        selectionLayer.anchorPoint = CGPoint()
        selectionLayer.frame = NSRect(x: 0, y: 0, width: layer.frame.width, height: layer.frame.height)
        selectionLayer.setNeedsDisplay()
        selectionLayer.backgroundColor = NSColor(white: 1, alpha: 0).cgColor
        selectionLayer.name = "SelectionLayer"
        selectionLayer.zPosition = -1
        layer.addSublayer(selectionLayer)
    }

    func configureLayer() {
        let newActions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull()
        ]
        layer.actions = newActions
        layer.anchorPoint = CGPoint()
        layer.setNeedsDisplay()
        layer.backgroundColor = NSColor.clear.cgColor
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

    func invalidate() {
        guard !layer.needsDisplay() else { return }
        layer.setNeedsDisplay()
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

        image = image.fill(color: BeamColor.Editor.icon.nsColor)

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
            invalidateRendering()
        }
    }

    // TODO: Refactor this in two methods
    func updateChildrenVisibility(_ isVisible: Bool) {
        for c in children {
            guard c.visible != isVisible else { continue }
            c.visible = isVisible
            c.updateChildrenVisibility(isVisible && c.open)
            invalidateLayout()
        }
    }

    func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedRendering {
            contentsFrame = NSRect()

            contentsFrame.size.width = availableWidth
            contentsFrame = contentsFrame.rounded()

            if !selfVisible {
                contentsFrame.size.height = 0
            }

            invalidatedRendering = false
        }

        computedIdealSize = contentsFrame.size
        computedIdealSize.width = frame.width

        if computedIdealSize.width.isNaN || !computedIdealSize.width.isFinite {
            Logger.shared.logError("computedIdealSize.width is not integral \(computedIdealSize.width)", category: .noteEditor)
            computedIdealSize.width = availableWidth
        }

        if computedIdealSize.height.isNaN || !computedIdealSize.height.isFinite {
            Logger.shared.logError("computedIdealSize.height is not integral \(computedIdealSize.height)", category: .noteEditor)
            computedIdealSize.height = 0
        }

        for c in children {
            computedIdealSize.height += c.idealSize.height
        }
    }

    // MARK: - Methods Widget

    func addChild(_ child: Widget) {
        guard !children.contains(child) else { return }
        children.append(child)
        invalidateLayout()
    }

    func removeChild(_ child: Widget) {
        guard children.contains(child) else { return }
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

        layer.layer.deepContentsScale = self.layer.contentsScale

        if global {
            editor.addToMainLayer(layer.layer)
            layer.layer.isHidden = !inVisibleBranch
        } else if layer.layer.superlayer == nil {
            self.layer.addSublayer(layer.layer)
            assert(layer.layer.superlayer == self.layer)

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

        for c in children {
            var i = mouseInfo
            i.position.x -= c.frame.origin.x
            i.position.y -= c.frame.origin.y
            if let d = c.dispatchMouseDown(mouseInfo: i) {
                return d
            }
        }

        let rect = NSRect(origin: CGPoint(), size: frame.size)
        guard rect.contains(mouseInfo.position) else {
            return nil
        }

//        Logger.shared.logDebug("dispatch down: \(mouseInfo.position)")
        if mouseDown(mouseInfo: mouseInfo) {
            return self
        }

        return contentsFrame.contains(mouseInfo.position) ? self : nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> Widget? {
        guard inVisibleBranch else { return nil }
        guard let mouseHandler = root?.mouseHandler else { return nil }

        if mouseHandler.handleMouseUp(mouseInfo: mouseInfo) {
            return mouseHandler
        }

        return nil
    }

    func handleMouseUp(mouseInfo: MouseInfo) -> Bool {
        defer {
            clickedLayer = nil
        }
        let info = MouseInfo(self, mouseInfo.globalPosition, mouseInfo.event)
//        Logger.shared.logDebug("dispatch up: \(info.position) vs \(mouseInfo.position)")

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
        guard let mouseHandler = root?.mouseHandler else { return nil }

        if mouseHandler.handleMouseDragged(mouseInfo: mouseInfo) {
            return mouseHandler
        }

        return nil
    }

    func focus(position: Int? = 0) {
        root?.focus(widget: self, position: position)
    }

    func onFocus() {
    }

    func onUnfocus() {
    }

    var isFocused: Bool {
        root?.focusedWidget == self
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
        if debug {
            let inContentsFrame = contentsFrame.contains(mouseInfo.position)
            Logger.shared.logInfo("mouse moved pos \(mouseInfo.position) \(inContentsFrame ? "Contents" : "")")
        }
        return false
    }

    weak var clickedLayer: Layer?
    func handleMouseDragged(mouseInfo: MouseInfo) -> Bool {
        let info = MouseInfo(self, mouseInfo.globalPosition, mouseInfo.event)
//        Logger.shared.logDebug("handle dragged: \(info.position) vs \(mouseInfo.position)")

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
// //            + text.text + "\n"
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
        let bounds = NSRect(origin: .zero, size: currentFrameInDocument.size)
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
        //swiftlint:disable:next print
        print("\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers")
        for c in children {
            c.dumpWidgetTree(level + 1)
        }
    }

    func proxyFor(_ element: BeamElement) -> ProxyElement? {
        return nodeProvider?.proxyFor(element) ?? parent?.proxyFor(element)
    }

    func nodeFor(_ element: BeamElement) -> ElementNode? {
        return nodeProvider?.nodeFor(element) ?? parent?.nodeFor(element)
    }

    func nodeFor(_ element: BeamElement, withParent: Widget) -> ElementNode {
        if let nodeProvider = nodeProvider { return nodeProvider.nodeFor(element, withParent: withParent) }
        guard let parent = parent else { fatalError("Trying to access element that is not connected to root") }
        return parent.nodeFor(element, withParent: withParent)
    }

    func removeNode(_ node: ElementNode) {
        if let nodeProvider = nodeProvider { nodeProvider.removeNode(node); return }
        guard let parent = parent else { Logger.shared.logError("Trying to access element that is not connected to root", category: .document); return }
        parent.removeNode(node)
    }

    func clearMapping() {
        if let nodeProvider = nodeProvider { nodeProvider.clearMapping(); return }
        for c in children {
            c.clearMapping()
        }
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
        //        Logger.shared.logDebug("\(Self.self) actualY = \(actualY) - rect \(rect) - parentRect \(parentRect) -> \(correctedRect)")
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

    var cmdManager: CommandManager<Widget> {
        guard let root = root else { fatalError("Trying to access the command manager on an unconnected Widget is a programming error.") }
        return root.cmdManager
    }

}

extension Widget {
    func presentMenu(with items: [ContextMenuItem], at: CGPoint) {
        let menuView = ContextMenuFormatterView(items: items, direction: .bottom) {
            ContextMenuPresenter.shared.dismissMenu()
        }
        let point = CGPoint(x: offsetInDocument.x + at.x, y: offsetInDocument.y + at.y)
        let atPoint = editor.convert(point, to: nil)
        editor.inlineFormatter = menuView
        ContextMenuPresenter.shared.presentMenu(menuView, atPoint: atPoint, animated: true)

    }
}

extension Widget {
    func hightlight() {
        let animation = CAKeyframeAnimation(keyPath: "backgroundColor")
        let sanskrit = BeamColor.Sanskrit.nsColor
        let colr = sanskrit.withAlphaComponent(0.14).cgColor
        animation.values = [colr,
                            colr,
                            sanskrit.withAlphaComponent(0).cgColor]
        animation.keyTimes = [0, 0.66, 1]
        animation.duration = 3
        layer.add(animation, forKey: "backgroundColor")
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
