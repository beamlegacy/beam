//
//  BlockReferenceNode.swift
//  Beam
//
//  Created by Sebastien Metrot on 04/06/2021.
//

import Foundation
import AppKit
import BeamCore

class BlockReferenceNode: TextNode {
    var blockReference: ProxyTextNode?
    private var gutterItem: GutterItem?

    override var hover: Bool {
        didSet {
            updateLayoutOnHover()
        }
    }

    override var isFocused: Bool {
        super.isFocused || (readOnly && isAChildProxyNodeFocused)
    }

    private var isAChildProxyNodeFocused: Bool {
        (root?.focusedWidget as? ProxyNode)?.allParents.contains(self) == true
    }

    override var readOnly: Bool {
        get { super.readOnly }
        set {
            super.readOnly = newValue
            onReadOnlyChanged(newValue)
        }
    }

    init(parent: Widget, element: BeamElement, availableWidth: CGFloat?) {
        super.init(parent: parent, element: element, nodeProvider: NodeProviderImpl(proxy: true), availableWidth: availableWidth)

        setupBlockReference()
    }

    init(editor: BeamTextEdit, element: BeamElement, availableWidth: CGFloat?) {
        super.init(editor: editor, element: element, nodeProvider: NodeProviderImpl(proxy: true), availableWidth: availableWidth)

        setupBlockReference()
    }

    deinit {
        if let gutterItem = gutterItem {
            editor?.removeGutterItem(item: gutterItem, fromLeadingGutter: false)
        }
    }

    static let lockButtonName = "lock"

    private func onReadOnlyChanged(_ readOnly: Bool) {
        self.cursor = readOnly ? .arrow : nil
        if let lockButton = self.layers[Self.lockButtonName] as? LockButton {
            lockButton.locked = readOnly
        }
    }

    func setupBlockReference() {
        self.readOnly = true
        var updatedPadding = contentsPadding
        updatedPadding.left -= 6
        contentsPadding = updatedPadding

        var refNoteId: UUID
        var refElementId: UUID

        switch element.kind {
        case let .blockReference(noteid, elid, _):
            refNoteId = noteid
            refElementId = elid
        default:
            Logger.shared.logError("A BlockReferenceNode must contain a block reference element instead of \(element.kind)", category: .noteEditor)
            return
        }

        guard let referencingNote = BeamNote.fetch(id: refNoteId, includeDeleted: false),
              let referencingElement = referencingNote.findElement(refElementId)
        else {
            let errorText = "BlockReferenceNode unable to fetch bloc from note '\(String(describing: refNoteId))'\nid '\(String(describing: refElementId))'"
            Logger.shared.logError(errorText, category: .noteEditor)
            addLayer(Layer.text(named: "ErrorDisplay", errorText), origin: CGPoint(x: childInset, y: 0), global: false)
            return
        }

        displayedElement = referencingElement
        referencingElement.$children
            .sink { [weak self] elements in
                guard self?.editor != nil else { return }
                self?.updateTextChildren(elements: elements)
            }.store(in: &scope)

        useActionLayer = false
        let lockButton = LockButton(Self.lockButtonName, locked: true, changed: { [unowned self] lock in
            self.readOnly = lock
        })
        lockButton.cursor = .arrow
        lockButton.layer.opacity = 0.0
        addLayer(lockButton)

        let item = GutterItem(id: self.elementId, title: referencingNote.title, icon: "field-card") { [weak self] in
            self?.openReferencedCard()
        }
        editor?.addGutterItem(item: item, toLeadingGutter: false)
        gutterItem = item
        setAccessibilityLabel("BlockReferenceNode")
        setAccessibilityRole(.textArea)

        open = false
    }

    static let blockLayerName = "blockLayerName"
    func createBlockLayerIfNeeded() -> Layer {
        guard let l = layers[Self.blockLayerName] else {
            let _blockLayer = CALayer()
            _blockLayer.cornerRadius = 3
            _blockLayer.zPosition = -1
            let blockLayer = Layer(name: Self.blockLayerName, layer: _blockLayer)
            addLayer(blockLayer)
            updateBackgroundColor(hover: hover)
            return blockLayer
        }

        return l
    }

    override func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
    }

    override func onFocus() {
        updateBackgroundColor(hover: hover)
    }

    override func onUnfocus() {
        updateBackgroundColor(hover: hover)
    }

    override func updateCursor() {
        if readOnly {
            updateElementCursor()
        } else {
            super.updateCursor()
        }
    }

    override func updateLayout() {
        super.updateLayout()

        let blockLayer = createBlockLayerIfNeeded()
        var f = contentsFrame
        f.origin.y -= 5
        f.size.height = idealSize.height
        blockLayer.frame = f

        if let lockButton = layers[Self.lockButtonName] {
            lockButton.frame = NSRect(origin: CGPoint(x: f.maxX + 10, y: 0), size: lockButton.frame.size)
        }
        self.gutterItem?.updateFrameFromNode(self)
    }

    private func updateBackgroundColor(hover: Bool) {
        var color: CGColor
        if readOnly && (isFocused || isAChildProxyNodeFocused) {
            color = BeamColor.Bluetiful.nsColor.withAlphaComponent(0.2).cgColor
        } else if hover {
            color = BeamColor.Nero.nsColor.add(BeamColor.Niobium.nsColor.withAlphaComponent(0.02)).cgColor
        } else {
            color = BeamColor.Nero.cgColor
        }
        createBlockLayerIfNeeded().layer.backgroundColor = color
    }

    private func updateLayoutOnHover() {
        gutterItem?.updateFrameFromNode(self)
        if let lockButton = layers[Self.lockButtonName] {
            lockButton.layer.opacity = hover ? 1.0 : 0.0
        }
        updateBackgroundColor(hover: hover)
    }

    private func openReferencedCard() {
        guard let noteid = self.displayedElement.note?.id else { return }
        self.editor?.openCard(noteid, self.displayedElement.id, self.open)
    }

    func showMenu(mouseInfo: MouseInfo) {
        let items = [
            ContextMenuItem(title: readOnly ? "Unlock" : "Lock", action: { [unowned self] in
                self.readOnly.toggle()
            }),
            ContextMenuItem(title: "View Origin", action: {
                self.openReferencedCard()
            }),

            ContextMenuItem(title: "Remove", action: {
                self.cmdManager.deleteElement(for: self.element, context: self)
            })
        ]

        presentMenu(with: items, at: mouseInfo.position)
    }

    override func mouseDown(mouseInfo: MouseInfo) -> Bool {
        guard mouseInfo.rightMouse else { return super.mouseDown(mouseInfo: mouseInfo) }
        showMenu(mouseInfo: mouseInfo)
        return true
    }

    override var textCount: Int {
        readOnly ? 1 : super.textCount
    }

}
