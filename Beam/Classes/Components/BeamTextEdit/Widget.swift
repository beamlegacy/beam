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
    var hasValidNodeProvider: Bool { nodeProvider?.holder?.editor != nil }
    var isInNodeProviderTree: Bool { hasValidNodeProvider || (parent?.isInNodeProviderTree ?? false) }
    var isTreeBoundary: Bool { nodeProvider != nil }

    var isEmpty: Bool { children.isEmpty }
    let selectionInset: CGFloat = 5
    var selectionLayerPosX: CGFloat = 0
    var selectedAlone: Bool = true {
        didSet {
            invalidate()
            invalidateLayout()
        }
    }

    func runBeforeNextLayout(_ block: @escaping () -> Void) {
        editor?.runBeforeNextLayout(block)
    }

    func runAfterNextLayout(_ block: @escaping () -> Void) {
        editor?.runAfterNextLayout(block)
    }

    var selected: Bool = false {
        didSet {
            selectionLayer.removeAllAnimations()
            selectionLayer.backgroundColor = selected ?
                BeamColor.Generic.textSelection.cgColor :
                NSColor(white: 1, alpha: 0).cgColor
            invalidate()
            invalidateLayout()
        }
    }

    var contentsScale = CGFloat(0) {
        didSet {
            guard contentsScale != oldValue else { return }
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
            updateVisible()
        }
    }

    var visible = true {
        didSet {
            updateVisible()
        }
    }

    func updateVisible() {
        runAfterNextLayout {
            self.updateLayersVisibility()
        }
        invalidateLayout()
        invalidateRendering()
    }

    var disableAnimationsForNextLayout = true

    func updateLayersVisibility() {
        disableAnimationsForNextLayout = layer.isHidden
        layer.isHidden = !visible || !selfVisible
        for l in layers where l.value.layer.superlayer == editor?.layer {
            l.value.layer.isHidden = !visible || !selfVisible
        }
    }

    var invalidateOnHover = true
    var hover: Bool = false {
        didSet {
            guard invalidateOnHover else { return }
            invalidate()
        }
    }

    var cursor: NSCursor?

    internal var children: [Widget] = [] {
        didSet {
            updateChildren(oldValue)
            invalidateLayout()
        }
    }

    var changingChildren = false
    func updateChildren(_ oldValue: [Widget]? = nil) {
        guard !changingChildren else { return }
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
        updateChildrenVisibility()
    }

    func updateAddedChild(child: Widget) {
        child.parent = self
        child.availableWidth = childAvailableWidth
        child.contentsScale = contentsScale
        editor?.addToMainLayer(child.layer)
        for l in child.layers where l.value.layer.superlayer == nil {
            editor?.addToMainLayer(l.value.layer)
        }

        child.attachChildrenLayers()
        let isVisible = visible && open
        child.visible = isVisible
        child.updateChildrenVisibility()
    }

    func updateRemovedChild(child: Widget) {
        // Remove layers for previous children that haven't been reattached to the editor:
        if child.parent === self || child.parent == nil {
            child.removeFromSuperlayer(recursive: true)
            child.parent = nil
            for l in child.layers where l.value.layer.superlayer == editor?.layer {
                l.value.layer.removeFromSuperlayer()
            }
        }
    }

    func attachChildrenLayers() {
        // Then make sure everything is correctly on screen
        for c in children {
            c.parent = self
            c.availableWidth = childAvailableWidth
            editor?.addToMainLayer(c.layer)
            for l in c.layers where l.value.layer.superlayer == nil {
                editor?.addToMainLayer(l.value.layer)
            }

            c.attachChildrenLayers()
        }
    }

    var depth: Int { return allParents.count }

    var enabled: Bool { editor?.enabled ?? false }
    var scope = Set<AnyCancellable>()

    var localTextFrame: NSRect { // The rectangle of our text excluding children
        return NSRect(x: 0, y: 0, width: contentsFrame.width, height: contentsFrame.height)
    }

    var availableWidth: CGFloat = 1 {
        didSet {
            guard availableWidth != oldValue else { return }
            updateChildren()
            invalidatedRendering = true
            computeRendering()
        }
    }

    var frame = NSRect(x: 0, y: 0, width: 0, height: 0) // the total frame including text and children, in the parent reference
    var localFrame: NSRect { // the total frame including text and children, in the local reference
        return NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }

    final var contentsFrame: NSRect { NSRect(x: contentsLead, y: contentsTop, width: idealContentsSize.width, height: idealContentsSize.height) }
    var idealContentsHeight: CGFloat = 0
    final var idealContentsSize: NSSize { NSSize(width: contentsWidth.rounded(.awayFromZero), height: idealContentsHeight.rounded(.awayFromZero))}
    final var paddedContentsSize: NSSize {
        NSSize(width: idealContentsSize.width + contentsPadding.left + contentsPadding.right,
               height: idealContentsSize.height + contentsPadding.top + contentsPadding.bottom).rounded()
    }

    var idealSizeChanged = true
    final var idealSize: NSSize {
        if idealSizeChanged {
            if debug {
                Logger.shared.logInfo("compute idealSize \(self) [before: \(computedIdealSize)] - paddedContentsSize: \(paddedContentsSize) - idealChildrenSize: \(idealChildrenSize) - padding: \(padding) (idealContentsSize: \(idealContentsSize))")
            }

            defer {
                if debug {
                    Logger.shared.logInfo("compute idealSize \(self) [after: \(computedIdealSize)] - paddedContentsSize: \(paddedContentsSize) - idealChildrenSize: \(idealChildrenSize) - padding: \(padding) (idealContentsSize: \(idealContentsSize))")
                }
            }
            computeRendering()
            computedIdealSize = NSSize(width: availableWidth, height: paddedContentsSize.height + idealChildrenSize.height + padding.top + padding.bottom).rounded()
            editor?.appendToCurrentIndicativeLayoutHeight(computedIdealSize.height)

            if computedIdealSize.width.isNaN || !computedIdealSize.width.isFinite {
                Logger.shared.logError("computedIdealSize.width is not integral \(computedIdealSize.width)", category: .noteEditor)
                computedIdealSize.width = availableWidth
            }

            if computedIdealSize.height.isNaN || !computedIdealSize.height.isFinite {
                Logger.shared.logError("computedIdealSize.height is not integral \(computedIdealSize.height)", category: .noteEditor)
                computedIdealSize.height = 0
            }
        }
        return computedIdealSize
    }

    var widgetWidth: CGFloat { (availableWidth - padding.left - padding.right).rounded(.awayFromZero) }
    var contentsWidth: CGFloat { (widgetWidth - contentsPadding.left - contentsPadding.right).rounded(.awayFromZero) }
    var childrenWidth: CGFloat { (widgetWidth - childInset - childrenPadding.left - childrenPadding.right).rounded(.awayFromZero) }

    var childrenTop: CGFloat { (padding.top + childrenPadding.top + paddedContentsSize.height).rounded(.awayFromZero) }
    var childrenLead: CGFloat { (childInset + padding.left + childrenPadding.left).rounded(.awayFromZero) }

    var contentsTop: CGFloat { (padding.top + contentsPadding.top).rounded(.awayFromZero) }
    var contentsLead: CGFloat { (padding.left + contentsPadding.left).rounded(.awayFromZero) }

    var idealChildrenSize: NSSize {
        guard open else { return NSSize() }
        var size = NSSize(width: childrenWidth, height: childrenPadding.top + childrenPadding.bottom + CGFloat(max(0, children.count - 1)) * childrenSpacing)
        for c in children {
            size.height += c.idealSize.height
        }
        return NSSize(width: size.width.rounded(.awayFromZero), height: size.height.rounded(.awayFromZero))
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

    weak var parent: Widget? {
        didSet {
            guard parent != oldValue else { return }
            if parent == nil && oldValue?.root?.focusedWidget === self {
                oldValue?.root?.focusedWidget = nil
            }

            if parent != nil {
                updateChildrenVisibility()
            }

            _root = nil

            dispatchDidMoveToWindow(editor?.window)
        }
    }

    weak var root: TextRoot? {
        if let r = _root {
            return r
        }
        _root = parent?.root ?? (self as? TextRoot)
        return _root
    }

    var isBig: Bool {
        editor?.isBig ?? false
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

    func firstParentWithType<ParentType>(_ type: ParentType.Type) -> ParentType? {
        allParents.first(where: { $0 as? ParentType != nil }) as? ParentType
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

    public weak var editor: BeamTextEdit? {
        didSet {
            guard editor != oldValue else { return }
            if editor == nil {
                _root = nil
            }

            if let scale = editor?.window?.backingScaleFactor {
                contentsScale = scale
            }

            for child in children {
                child.editor = editor
            }

        }
    }

    internal var computedIdealSize = NSSize()
    private weak var _root: TextRoot?
    public private(set) var needLayout = false

    /// The app appearance at the time UI elements using dynamic colors were last updated.
    private var currentAppearance: NSAppearance?

    public static func == (lhs: Widget, rhs: Widget) -> Bool {
        return lhs === rhs
    }

    // MARK: - Initializer
    init(parent: Widget, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        self.parent = parent
        self.editor = parent.editor
        self.nodeProvider = nodeProvider
        layer = CALayer()
        layer.isHidden = true
        selectionLayer = CALayer()
        self.availableWidth = availableWidth
        super.init()
        setupWidget()
    }

    // this version should only be used by TextRoot
    init(editor: BeamTextEdit, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        self.editor = editor
        self.nodeProvider = nodeProvider
        layer = CALayer()
        layer.isHidden = true
        selectionLayer = CALayer()
        self.availableWidth = availableWidth
        super.init()
        setupWidget()
    }

    func setupWidget() {
        self.nodeProvider?.holder = self
        configureLayer()
        configureSelectionLayer()

        setupAccessibility()
        didMoveToWindow(editor?.window)
    }

    func setupAccessibility() {
        setAccessibilityIdentifier(String(describing: Self.self))
        setAccessibilityElement(true)
        setAccessibilityLabel("Widget")
        setAccessibilityRole(.unknown)
        setAccessibilityParent(editor)
    }

    deinit {
        removeFromSuperlayer(recursive: true)
    }

    func removeFromSuperlayer(recursive: Bool) {
        layer.removeFromSuperlayer()

        // handle sublayers:
        for l in layers where l.value.layer.superlayer?.name == BeamTextEdit.mainLayerName {
            l.value.layer.removeFromSuperlayer()
        }

        if recursive {
            for c in children where c.parent == self {
                c.removeFromSuperlayer(recursive: recursive)
            }
        }
    }

    // MARK: - Setup UI

    public func draw(_ layer: CALayer, in context: CGContext) {
        computeRendering()
        drawDebug(in: context)
    }

    func updateSubLayersLayout() { }

    fileprivate var initialLayout = true
    var inInitialLayout: Bool {
        initialLayout || (editor?.frame.isEmpty ?? true)
    }

    var shouldDisableActions: Bool {
        inInitialLayout || layer.isHidden || layer.frame.isEmpty || disableAnimationsForNextLayout
    }
    final func setLayout(_ frame: NSRect) {
        self.frame = frame
        defer {
            needLayout = false
            initialLayout = false
            disableAnimationsForNextLayout = false
        }

        let disableActions = shouldDisableActions
        if disableActions {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
        }

        layer.bounds = contentsFrame
        layer.position = CGPoint(x: frameInDocument.origin.x + contentsFrame.origin.x, y: frameInDocument.origin.y + contentsFrame.origin.y)

        if disableActions {
            CATransaction.commit()
        }

        layer.backgroundColor = debug ? NSColor.systemPink.withAlphaComponent(0.1).cgColor : nil

        updateSubLayersLayout()
        updateChildrenLayout()
        updateLayout()
        updateColorsIfNeeded()

        if self.currentFrameInDocument != frame {
            invalidatedRendering = true
            computeRendering()
            invalidate() // invalidate before change
            currentFrameInDocument = frame
            invalidate()  // invalidate after the change
        }
    }

    /// updateLayout() is called whenever the frame of this widget is updated. It is a change to change the position of custom layers. You must not relayout children in this method, it is done automatically for you.
    func updateLayout() {
    }

    var childInset: CGFloat = 18 { didSet { invalidateRendering() } }
    var childAvailableWidth: CGFloat { availableWidth - childInset }

    /// Padding around the Widget + its children
    var padding: NSEdgeInsets = NSEdgeInsetsZero { didSet { invalidateRendering() } }
    /// Padding around this widget's contents
    var contentsPadding: NSEdgeInsets = NSEdgeInsetsZero { didSet { invalidateRendering() } }
    /// Padding around this widget's children
    var childrenPadding: NSEdgeInsets = NSEdgeInsetsZero { didSet { invalidateRendering() } }
    /// Space in between two children
    var childrenSpacing: CGFloat = PreferencesManager.editorChildSpacing { didSet { invalidateRendering() } }

    final func updateChildrenLayout() {
        guard open else { return }
        var pos = NSPoint(x: childrenLead, y: childrenTop)
        var first = true
        for c in children {
            var childSize = c.idealSize
            childSize.width = childrenWidth
            if !first {
                pos.y += childrenSpacing
            }
            let childFrame = NSRect(origin: pos, size: childSize)
            c.setLayout(childFrame)
            pos.y += childSize.height
            first = false
        }
    }

    /// This method is called during a layout pass if the app appearance has changed since the previous pass, and when
    /// the app appearance has changed.
    ///
    /// You can override this method to set all UI elements using dynamic colors.
    ///
    /// If you override this method, call this method on super at some point in your implementation.
    func updateColors() {
        children.forEach { widget in
            widget.updateColorsIfNeeded()
        }

        layers.forEach { _, layer in
            layer.updateColorsIfNeeded()
        }
    }

    final func updateColorsIfNeeded() {
        // Stop if appearance has not changed since last pass
        guard currentAppearance == nil || (currentAppearance != NSApp.effectiveAppearance) else { return }
        updateColors()
        currentAppearance = NSApp.effectiveAppearance
    }

    var selectionLayerWidth: CGFloat {
        availableWidth + 20
    }

    var selectionLayerHeight: CGFloat {
        contentsFrame.height + contentsPadding.top + contentsPadding.bottom
    }

    var selectionLayerPosY: CGFloat {
        -2.5
    }

    private func configureSelectionLayer() {
        selectionLayer.anchorPoint = CGPoint()
        selectionLayer.cornerRadius = 2
        selectionLayer.frame = NSRect(x: 0, y: 0, width: layer.frame.width, height: layer.frame.height).rounded()
        selectionLayer.setNeedsDisplay()
        selectionLayer.backgroundColor = NSColor(white: 1, alpha: 0).cgColor
        selectionLayer.name = "SelectionLayer"
        selectionLayer.zPosition = -1
        layer.addSublayer(selectionLayer)
    }

    func configureLayer() {
        layer.isHidden = true
        selectionLayer.enableAnimations = false

        let newActions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            kCATransition: NSNull(),
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
        layer.masksToBounds = false
    }

    var mainLayerName: String {
        String(describing: self)
    }

    func onLayoutInvalidated() {
    }

    final func invalidateLayout() {
        guard !inInitialLayout else { return }
        invalidate()
        // TODO: fix this optimisation so that we don't go up the tree every time
//        guard !needLayout else {
//            checkTreeLayout()
//            return
//        }
        needLayout = true
        idealSizeChanged = true
        dispatchInvalidateLayout()
        onLayoutInvalidated()
    }

    final func checkTreeLayout() {
        guard inVisibleBranch else {
            return
        }
        guard needLayout else {
            Logger.shared.logError("checkTreeLayout Error - needLayout is false in \(self)", category: .noteEditor)
            return
        }
        parent?.checkTreeLayout()
    }

    final func dispatchInvalidateLayout() {
        guard let p = parent else { return }
        p.invalidateLayout()
    }

    final func invalidate() {
        guard !inInitialLayout, !layer.needsDisplay() else { return }
        layer.setNeedsDisplay()
    }

    final func invalidateRendering() {
        guard !inInitialLayout else { return }
        invalidatedRendering = true
        invalidateLayout()
    }

    final func deepInvalidateRendering() {
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
            updateChildrenVisibility()
            invalidateLayout()
            invalidateRendering()
        }
    }

    // TODO: Refactor this in two methods
    func updateChildrenVisibility() {
        let isVisible = visible && open
        for c in children {
            c.visible = isVisible
            editor?.addToMainLayer(c.layer)
            c.updateChildrenVisibility()
        }
    }

    final func computeRendering() {
        guard availableWidth > 0 else { return }
        invalidatedRendering = false
        idealContentsHeight = updateRendering()
    }

    /// updateRendering() must be overloaded to update the rendering of a widget and return the new height of its contents. It should not modify any layout information
    func updateRendering() -> CGFloat {
        0
    }

    // MARK: - Methods Widget

    func addChild(_ child: Widget) {
        guard !children.contains(child) else { return }
        changingChildren = true
        defer { changingChildren = false }
        children.append(child)
        updateAddedChild(child: child)
    }

    func removeChild(_ child: Widget) {
        guard children.contains(child) else { return }
        changingChildren = true
        defer { changingChildren = false }
        children.removeAll { w -> Bool in
            w === child
        }
        guard child.parent == self else { return }
        child.removeFromSuperlayer(recursive: true)

        updateRemovedChild(child: child)
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

    private var lock = RWLock()
    private var _layers: [String: Layer] = [:]
    internal var layers: [String: Layer] {
        get {
            lock.read { self._layers }
        }
        set {
            lock.write { self._layers = newValue }
        }
    }
    func addLayer(_ layer: Layer, origin: CGPoint? = nil, global: Bool = false) {
        CATransaction.disableAnimations {
            layer.widget = self
            layer.frame = CGRect(origin: origin ?? layer.frame.origin, size: layer.frame.size).rounded()

            layer.layer.deepContentsScale = self.layer.contentsScale

            layer.updateColorsIfNeeded()

            if global {
                editor?.addToMainLayer(layer.layer)
                layer.layer.isHidden = !inVisibleBranch
            } else if layer.layer.superlayer == nil {
                self.layer.addSublayer(layer.layer)
                assert(layer.layer.superlayer == self.layer)

                layer.setAccessibilityParent(self)
            }

            self.layers[layer.name] = layer
        }
    }

    func removeLayer(_ layer: Layer) {
        removeLayer(layer.name)
    }

    func removeLayer(_ name: String) {
        guard let l = layers[name] else { return }
        l.layer.removeFromSuperlayer()
        layers.removeValue(forKey: name)
    }

    func dispatchHover(_ widgets: Set<Widget>) {
        var isHovering = widgets.contains(self)
        for c in children {
            c.dispatchHover(widgets)
            isHovering = isHovering || c.hover
        }
        hover = isHovering
    }

    func dispatchMouseDown(mouseInfo: MouseInfo) -> Widget? {
        guard visible, inVisibleBranch else { return nil }

        clickedLayer = nil
        if selfVisible {
            for layer in layers.values.reversed() where !layer.layer.isHidden {
                let info = MouseInfo(self, layer, mouseInfo)
                if layer.contains(info.position) {
                    if layer.mouseDown(info) {
                        clickedLayer = layer
                        return self
                    }
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
        guard rect.containsY(mouseInfo.position) else {
            return nil
        }

//        Logger.shared.logDebug("dispatch down: \(mouseInfo.position)")
        if visible, mouseDown(mouseInfo: mouseInfo) {
            return self
        }

        return contentsFrame.contains(mouseInfo.position) ? self : nil
    }

    func dispatchMouseUp(mouseInfo: MouseInfo) -> Widget? {
        guard visible, inVisibleBranch else { return nil }
        guard let mouseHandler = root?.mouseHandler else { return nil }

        if visible, mouseHandler.handleMouseUp(mouseInfo: mouseInfo) {
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

    func getWidgetsAt(_ position: NSPoint, _ globalPosition: NSPoint, ignoreX: Bool = false) -> [MouseHandler] {
        guard inVisibleBranch else { return [] }
        var handlers: [MouseHandler] = {
            let inside = ignoreX
            ? layer.frame.minY <= globalPosition.y && globalPosition.y < layer.frame.maxY
            : layer.frame.contains(globalPosition)
            return inside ? [self] : []
        }()
        for c in children {
            var p = position
            p.x -= c.frame.origin.x
            p.y -= c.frame.origin.y

            handlers += c.getWidgetsAt(p, globalPosition, ignoreX: ignoreX)
        }

        for layer in layers.values.reversed() where !layer.layer.isHidden {
            let p = MouseInfo.convert(globalPosition: globalPosition, self, layer)
            if layer.contains(p, ignoreX: ignoreX) {
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
            n = p?.nextSibbling()
            p = p?.parent
        }

        if n != nil && n !== self {
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

    func dumpWidgetTree(_ level: Int = 0) -> [String] {
        let tabs = String.tabs(level)
        let str = "\(tabs)\(String(describing: Self.self)) frame(\(frame)) \(layers.count) layers"
        var strs = [str]
        for c in children {
            strs.append(contentsOf: c.dumpWidgetTree(level + 1))
        }

        return strs
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
        let parentRect = editor?.frame ?? .zero
        let rect = NSRect(origin: layer.position, size: layer.bounds.size)
        let actualY = parentRect.height - rect.maxY
        let correctedRect = NSRect(origin: CGPoint(x: rect.origin.x, y: actualY), size: rect.size)
        //        Logger.shared.logDebug("\(Self.self) actualY = \(actualY) - rect \(rect) - parentRect \(parentRect) -> \(correctedRect)")
        return correctedRect
    }

    var allVisibleChildren: [Widget] {
        //        guard inVisibleBranch else { return [] }
        guard visible else { return [] }
        var widgets: [Widget] = []

        for child in children where child.visible {
            if child.selfVisible && !child.frame.isEmpty {
                widgets.append(child)
            }
            widgets += child.allVisibleChildren
        }

        return widgets
    }

    var hasCmdManager: Bool {
        guard let root = root, root.note != nil else { return false }
        return true
    }

    var cmdManager: CommandManager<Widget> {
        guard let root = root else { fatalError("Trying to access the command manager on an unconnected Widget is a programming error.") }
        return root.cmdManager
    }

    func didMoveToWindow(_ window: NSWindow?) {
    }
}

extension Widget {
    func presentMenu(with items: [ContextMenuItem], at: CGPoint) {
        guard let editor = self.editor else { return }
        let menuView = ContextMenuFormatterView(key: "WidgetMenu", items: items, direction: .bottom) {
            CustomPopoverPresenter.shared.dismissPopovers(key: "WidgetMenu")
        }
        let point = CGPoint(x: offsetInDocument.x + at.x, y: offsetInDocument.y + at.y)
        let atPoint = editor.convert(point, to: nil)
        editor.inlineFormatter = menuView
        CustomPopoverPresenter.shared.presentFormatterView(menuView, atPoint: atPoint)
    }
}

extension Widget {
    func highlight() {
        let animation = CAKeyframeAnimation(keyPath: "backgroundColor")
        let sanskrit = BeamColor.Sanskrit.nsColor
        let colr = sanskrit.withAlphaComponent(0.14).cgColor
        animation.values = [colr,
                            colr,
                            sanskrit.withAlphaComponent(0).cgColor]
        animation.keyTimes = [0, 0.86, 1]
        animation.duration = 2.3
        selectionLayer.add(animation, forKey: "highlightBackgroundColor")
        children.forEach { c in
            c.highlight()
        }
    }
}

extension Widget {
    func dispatchDidMoveToWindow(_ window: NSWindow?) {
        didMoveToWindow(window)
        for child in children {
            child.dispatchDidMoveToWindow(window)
        }
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
