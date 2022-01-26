//
//  ElementNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 07/05/2021.
//

import Foundation
import AppKit
import NaturalLanguage
import Combine
import BeamCore

public protocol ProxyNode: ElementNode {}

extension ProxyNode {
    func highestParent() -> ProxyNode {
        if let parent = self.parent as? ProxyNode {
            return parent.highestParent()
        }
        return self
    }

    var isContainedInLink: Bool {
        self.highestParent().isLink || self.highestParent().childrenIsLink()
    }
}

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
public class ElementNode: Widget {
    var element: BeamElement { didSet {
        subscribeToElement(element)
    }}

    var elementId: UUID {
        unproxyElement.id
    }

    var elementNoteId: UUID? {
        unproxyElement.note?.id
    }

    var displayedElementId: UUID {
        displayedElement.id
    }

    var displayedElementNoteId: UUID? {
        displayedElement.note?.id
    }

    var _displayedElement: BeamElement?
    var displayedElement: BeamElement {
        get {
            _displayedElement ?? unproxyElement
        }
        set {
            _displayedElement = newValue
            subscribeToElement(newValue)
            invalidateText()
            invalidateLayout()
        }
    }

    var unproxyElement: BeamElement {
        guard let elem = element as? ProxyElement
        else {
            return element
        }
        return elem.proxy
    }

    var elementScope = Set<AnyCancellable>()
    var elementText = BeamText()
    var elementKind = ElementKind.bullet

    override var parent: Widget? {
        didSet {
            guard parent != nil, parent != oldValue else { return }
            updateTextChildren(elements: displayedElement.children)
        }
    }

    override var open: Bool {
        didSet {
            guard !inInitialLayout, element.open != open else { return }
            element.open = open
        }
    }

    var parentIsSelectedAndClosed: Bool {
        if let open = self.parent?.open, let selected = self.parent?.selected, !open && selected {
            return true
        } else {
            guard let parent = self.parent as? ElementNode else { return false }
            return parent.parentIsSelectedAndClosed
        }
    }

    var strippedText: String {
        ""
    }

    var fullStrippedText: String {
        children.reduce("") { partial, node -> String in
            guard let node = node as? ElementNode else { return partial }
            return partial + " " + node.fullStrippedText
        }
    }

    var config: TextConfig {
        root?.config ?? TextConfig()
    }

    var color: NSColor { config.color }
    var disabledColor: NSColor { config.disabledColor }
    var cursorColor: NSColor { config.cursorColor }
    var selectionColor: NSColor { config.selectionColor }
    var alpha: Float { config.alpha }
    var blendMode: CGBlendMode { config.blendMode }

    var showDisclosureButton: Bool {
        !children.isEmpty
    }

    var showIdentationLine: Bool {
        return depth == 1
    }

    var _readOnly: Bool?
    var readOnly: Bool {
        get {
            _readOnly ?? (parent as? ElementNode)?.readOnly ?? false
        }
        set {
            _readOnly = newValue
        }
    }
    var isEditing: Bool {
        guard let r = root else { return false }
        return r.focusedWidget === self && r.state.nodeSelection == nil
    }

    var firstLineHeight: CGFloat {
        return 0
    }
    var firstLineBaseline: CGFloat {
        let f = BeamText.font(10)
        return f.ascender
    }

    // walking the node tree:
    var inOpenBranch: Bool {
        guard let p = parent as? ElementNode else { return true }
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

    private let debounceClickInterval = 0.23

    private var actionLayerPadding = CGFloat(3.5)

    public static func == (lhs: ElementNode, rhs: ElementNode) -> Bool {
        return lhs === rhs
    }

    func buildTextChildren(elements: [BeamElement]) -> [Widget] {
        guard isInNodeProviderTree else { return [] }
        return elements.map { childElement -> ElementNode in
            nodeFor(childElement, withParent: self)
        }
    }

    func updateTextChildren(elements: [BeamElement]) {
        guard isInNodeProviderTree else { return }
        children = buildTextChildren(elements: elements)
    }

    // MARK: - Initializer

    init(parent: Widget, element: BeamElement, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        self.element = element
        super.init(parent: parent, nodeProvider: nodeProvider, availableWidth: availableWidth)

        setupElementNode()
    }

    init(editor: BeamTextEdit, element: BeamElement, nodeProvider: NodeProvider? = nil, availableWidth: CGFloat) {
        self.element = element

        super.init(editor: editor, nodeProvider: nodeProvider, availableWidth: availableWidth)

        setupElementNode()
    }

    func setupElementNode() {
        contentsPadding.left = 18
        createElementLayers()

        displayedElement.$children
            .removeDuplicates()
            .sink { [unowned self] elements in
                guard (self.parent != nil) || (self as? TextRoot != nil) else { return }
                updateTextChildren(elements: elements)
            }.store(in: &scope)

        PreferencesManager.$alwaysShowBullets.sink { [unowned self] _ in
            invalidateLayout()
        }.store(in: &scope)

        subscribeToElement(element)
    }

    // MARK: - Setup UI
    override func setupAccessibility() {
        super.setupAccessibility()
        setAccessibilityLabel("ElementNode")
        setAccessibilityRole(.textArea)
    }

    override func updateSubLayersLayout() {
        super.updateSubLayersLayout()
        updateSelectionLayer()
        setBottomPaddings()
    }

    func updateSelectionLayer() {
        guard selected else { return }

        let selectionLayerPos = CGPoint(x: Self.indentLayerPosX - childInset, y: selectionLayerPosY)

        if selectedAlone {
            selectionLayer.position = selectionLayerPos
            selectionLayer.bounds.size = CGSize(width: selectionLayerWidth,
                                                height: selectionLayerHeight)
        } else {
            guard let parent = self.parent else { return }

            selectionLayer.position = selectionLayerPos
            selectionLayer.position.x += selectionLayerPosX
            selectionLayer.position.y -= parent.childrenSpacing
            selectionLayer.bounds.size = CGSize(width: selectionLayerWidth - selectionLayerPosX,
                                                height: selectionLayerHeight + parent.childrenSpacing)
            if !self.children.isEmpty && self.open {
                selectionLayer.bounds.size.height -= childrenSpacing
            }
        }
    }

    func deepInvalidateText() {
        for c in children {
            guard let c = c as? ElementNode else { continue }
            c.deepInvalidateText()
        }
    }

    func setBottomPaddings(withDefault: CGFloat = 0) {
        // WARNING
        // Be extra carefull when changing values
        //
        // Padding bottom of Node depending of the nextElement with higher or smaller depth
        if let nextElement = element.nextElement() {
            var newPadding: CGFloat = withDefault

            if self.open {
                if nextElement.depth > depth, parent !== root?.element {
                    newPadding += nextElement.isHeader ? 2 : 1
                } else if nextElement.depth < depth {
                    if nextElement.parent === root?.element {
                        newPadding += nextElement.isHeader ? 7 : 0
                    } else {
                        newPadding += nextElement.isHeader ? 5 : 0
                    }
                }
            } else {
                if isHeader {
                    newPadding = 4
                }
            }

            if contentsPadding.bottom != newPadding {
                contentsPadding.bottom = newPadding
            }
        }

        for child in children {
            guard let c = child as? ElementNode else { continue }
            c.setBottomPaddings()
        }
    }

    // MARK: - Methods ElementNode
    override func delete() {
        guard let parent = parent as? ElementNode else { return }
        parent.element.removeChild(element)
    }

    override func insert(node: Widget, after existingNode: Widget) -> Bool {
        guard let node = node as? ElementNode, let existingNode = existingNode as? ElementNode else { fatalError() }
        element.insert(node.element, after: existingNode.element)
        invalidateLayout()
        return true
    }

    @discardableResult
    override func insert(node: Widget, at pos: Int) -> Bool {
        guard let node = node as? ElementNode else { fatalError() }
        element.insert(node.element, at: pos)
        invalidateLayout()
        return true
    }

    func fold() {
        if children.isEmpty {
            guard let p = parent as? ElementNode else { return }
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

    // MARK: - Mouse Events

    override var hover: Bool {
        didSet {
            updateElementLayers()
        }
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        if mouseInfo.position.x < contentsFrame.width / 2 {
            focus(position: 0)
        } else {
            focus(position: 1)
        }
        dragMode = .select(0)
        return true
    }

    override public func printTree(level: Int = 0) -> String {
        String.tabs(level)
            + (children.isEmpty ? "- " : (open ? "v - " : "> - "))
            + "element\n"
            + (open ?
                children.reduce("", { result, child -> String in
                    result + child.printTree(level: level + 1)
                })
                : "")
    }

    // MARK: - Private Methods

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

    func openExternalLink(link: URL, element: BeamElement) {
        editor?.hideInlineFormatter()
        editor?.openURL(link, element)
    }

    func nextVisibleNode<NodeType: Widget>(_ type: NodeType.Type) -> NodeType? {
        var node = nextVisible()
        while node != nil {
            if let elementNode = node as? NodeType {
                return elementNode
            }
            let next = node?.nextVisible()
            assert(next != node)
            node = next
        }

        return nil
    }

    func lastVisibleNode<NodeType: Widget>(_ type: NodeType.Type) -> NodeType? {
        children.reversed().first { widget in
            return widget.visible && widget is NodeType
        } as? NodeType
    }

    func firstVisibleNode<NodeType: Widget>(_ type: NodeType.Type) -> NodeType? {
        children.first { widget in
            return widget.visible && widget is NodeType
        } as? NodeType
    }

    func previousVisibleNode<NodeType: Widget>(_ type: NodeType.Type) -> NodeType? {
        var node = previousVisible()
        while node != nil {
            if let elementNode = node as? NodeType {
                return elementNode
            }
            let previous = node?.previousVisible()
            assert(previous != node)
            node = previous
        }

        return nil
    }

    var previousNodeIsRoot: Bool {
        ((self.previousWidget() as? TextRoot) != nil)
    }

    func isAbove(node: ElementNode) -> Bool {
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

    public func deepestElementNodeChild() -> ElementNode {
        for c in children.reversed() {
            if let c = c as? ElementNode {
                return c.deepestElementNodeChild()
            }
        }
        return self
    }

    override func dumpWidgetTree(_ level: Int = 0) -> [String] {
        let tabs = String.tabs(level)
        var strs = ["\(tabs)\(String(describing: Self.self)) - \(String(describing: self))) frame(\(frame)) \(layers.count) layers - element id: \(element.id) [\(elementText.text)]\(layer.superlayer == nil ? " DETTACHED" : "") \(needLayout ? "NeedLayout":"")"]
        for c in children {
            strs.append(contentsOf: c.dumpWidgetTree(level + 1))
        }
        return strs
    }

    override var mainLayerName: String {
        "\(Self.self) - \(element.id.uuidString)"
    }

    func subscribeToElement(_ element: BeamElement) {
        elementScope.removeAll()

        element.$text
            .sink { [unowned self] newValue in
                elementText = newValue
            }.store(in: &elementScope)

        element.$kind
            .sink { [unowned self] newValue in
                elementKind = newValue
            }.store(in: &elementScope)

        element.$open
            .sink { [unowned self] newValue in
                if open != newValue {
                    open = newValue
                }
            }.store(in: &elementScope)

        element.$hasNote
            .drop(while: { newValue in newValue == false })
            .sink { [unowned self] newValue in
                if newValue {
                    willBeAddedToNote()
                } else {
                    willBeRemovedFromNote()
                }
            }.store(in: &elementScope)

        elementText = element.text
        elementKind = element.kind
    }

    // Override these two methods if you need to know when a beem element will be added or removed from a note
    func willBeRemovedFromNote() { }
    func willBeAddedToNote() { }

    // The default implementation doesn't know anything about text
    public func indexOnLastLine(atOffset x: CGFloat) -> Int {
        1
    }

    // The default implementation doesn't know anything about text
    public func indexOnFirstLine(atOffset x: CGFloat) -> Int {
        0
    }

    public func isOnFirstLine(_ position: Int) -> Bool {
        true
    }

    public func isOnLastLine(_ position: Int) -> Bool {
        true
    }

    public func offsetAt(index: Int) -> CGFloat {
        index > 0 ? availableWidth : 0
    }

    public func invalidateText() {
    }

    public func caretIndexForSourcePosition(_ index: Int) -> Int? {
        return index
    }

    public var textCount: Int {
        1
    }

    var _cursorLayer: ShapeLayer?
    var cursorLayer: ShapeLayer {
        if let layer = _cursorLayer {
            return layer
        }

        let layer = ShapeLayer(name: "cursor")
        layer.layer.actions = [
            kCAOnOrderIn: NSNull(),
            kCAOnOrderOut: NSNull(),
            "sublayers": NSNull(),
            "contents": NSNull(),
            "bounds": NSNull()
        ]

        layer.layer.zPosition = 100
        layer.layer.position = CGPoint(x: contentsLead, y: contentsTop)
        _cursorLayer = layer
        addLayer(layer)
        return layer
    }

    public func updateCursor() {
        updateElementCursor()
    }

    public func layoutCursor(_ cursorRect: NSRect) {
        guard let editor = self.editor else { return }
        let on = AppDelegate.main.isActive && AppDelegate.main.window?.isKeyWindow == true
            && editor.hasFocus && isFocused && editor.blinkPhase && (root?.state.nodeSelection?.nodes.isEmpty ?? true)

        let layer = self.cursorLayer

        layer.shapeLayer.fillColor = enabled ? cursorColor.cgColor : disabledColor.cgColor
        layer.layer.isHidden = !on
        layer.shapeLayer.path = CGPath(rect: cursorRect, transform: nil)
    }

    public func updateElementCursor() {
        guard let editor = self.editor else { return }
        let on = editor.hasFocus && isFocused && editor.blinkPhase && (root?.state.nodeSelection?.nodes.isEmpty ?? true)
        let cursorRect = NSRect(x: caretIndex == 0 ? (contentsLead - 5) : (availableWidth - contentsLead + 3), y: 0, width: 2, height: frame.height )//rectAt(caretIndex: caretIndex)
        let layer = self.cursorLayer

        layer.shapeLayer.fillColor = enabled ? cursorColor.cgColor : disabledColor.cgColor
        layer.layer.isHidden = !on
        layer.shapeLayer.path = CGPath(rect: cursorRect, transform: nil)
    }

    func updateFocus() {}

    override func onFocus() {
        super.onFocus()
        updateCursor()
    }

    override func onUnfocus() {
        super.onUnfocus()
        updateCursor()
    }

    let smallCursorWidth = CGFloat(2)
    let bigCursorWidth = CGFloat(7)
    var maxCursorWidth: CGFloat { max(smallCursorWidth, bigCursorWidth) }
    var cursorPosition: Int { root?.cursorPosition ?? 0 }
    var caretIndex: Int { root?.caretIndex ?? 0 }

    public func rectAt(caretIndex: Int) -> NSRect {
        let cursorRect = NSRect(x: contentsLead + CGFloat(caretIndex == 0 ? 0 : contentsFrame.width - contentsLead), y: 0, width: caretIndex == textCount ? bigCursorWidth : smallCursorWidth, height: contentsFrame.height)

        return cursorRect
    }

    override public func draw(_ layer: CALayer, in context: CGContext) {
        super.draw(layer, in: context)
        updateCursor()
        updateElementLayers()
    }

    // MARK: needed for proxied nodes

    // override the following 2 methods in the proxies:
    func isLinkToNote(_ text: BeamText) -> Bool {
        false
    }

    var isLink: Bool {
        false
    }

    func childrenIsLink() -> Bool {
        for c in children {
            guard let linkedRef = c as? ElementNode else { return false }
            if linkedRef.isLink {
                return linkedRef.isLink
            }
            if linkedRef.childrenIsLink() {
                return true
            }
        }
        return isLink
    }

    // MARK: Search

    var searchHighlightRanges: [Range<Int>] = []
    var currentSearchHightlight: Int?

    // MARK: Positions and carets

    public func position(after index: Int, avoidUneditableRange: Bool = false) -> Int {
        return min(1, index + 1)
    }

    public func position(before index: Int, avoidUneditableRange: Bool = false) -> Int {
        return max(0, index - 1)
    }

    public func caretAbove(_ caretIndex: Int) -> Int {
        return max(0, caretIndex - 1)
    }

    public func caretBelow(_ caretIndex: Int) -> Int {
        return min(1, caretIndex + 1)
    }

    public func positionForCaretIndex(_ caretIndex: Int) -> Int {
        caretIndex
    }

    public func caretIndexAvoidingUneditableRange(_ caretIndex: Int, after: Bool) -> Int? {
        after ? min(1, caretIndex + 1) : caretIndex
    }

    public func caretAtIndex(_ index: Int) -> Caret {
        let actualIndex = index.clamp(0, textCount)
        let point = NSPoint(x: contentsLead + CGFloat(caretIndex == 0 ? 0 : contentsFrame.width - contentsLead), y: 0)

        return Caret(offset: point, indexInSource: actualIndex, indexOnScreen: actualIndex, edge: actualIndex == 0 ? .leading : .trailing, inSource: true, line: 0)
    }

    override var cmdManager: CommandManager<Widget> {
        return displayedElement.note?.cmdManager ?? super.cmdManager
    }

    public func clampTextRange(_ range: Range<Int>) -> Range<Int> {
        max(0, range.lowerBound)..<min(textCount, range.upperBound)
    }

}
