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

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element, nodeProvider: NodeProviderImpl(proxy: true))

        setupBlockReference()
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element, nodeProvider: NodeProviderImpl(proxy: true))

        setupBlockReference()
    }

    override func willBeRemovedFromNote() {
        super.willBeRemovedFromNote()
        if let gutterItem = gutterItem {
            editor?.removeGutterItem(item: gutterItem)
        }
    }

    static let lockButtonName = "lock"

    private func updateReadOnlyMode(_ readOnly: Bool) {
        self.readOnly = readOnly
        self.cursor = readOnly ? .arrow : nil
    }

    func setupBlockReference() {
        updateReadOnlyMode(true)
        var refNoteId: UUID
        var refElementId: UUID

        switch element.kind {
        case let .blockReference(noteid, elid):
            refNoteId = noteid
            refElementId = elid
        default:
            Logger.shared.logError("A BlockReferenceNode must contain a block reference element instead of \(element.kind)", category: .noteEditor)
            return
        }

        guard let referencingNote = BeamNote.fetch(DocumentManager(), id: refNoteId),
              let referencingElement = referencingNote.findElement(refElementId)
        else {
            let errorText = "BlockReferenceNode unable to fetch bloc from note '\(String(describing: refNoteId))'\nid '\(String(describing: refElementId))'"
            Logger.shared.logError(errorText, category: .noteEditor)
            addLayer(Layer.text(named: "ErrorDisplay", errorText), origin: CGPoint(x: childInset, y: 0), global: false)
            return
        }

        displayedElement = referencingElement
        referencingElement.$children
            .sink { elements in
                super.updateTextChildren(elements: elements)
            }.store(in: &scope)

        useActionLayer = false
        let lockButton = LockButton(Self.lockButtonName, locked: true, changed: { [unowned self] lock in
            updateReadOnlyMode(lock)
        })
        lockButton.cursor = .arrow
        lockButton.layer.opacity = 0.0
        addLayer(lockButton)

        let item = GutterItem(id: self.elementId, title: referencingNote.title, icon: "field-card") { [weak self] in
            self?.openReferencedCard()
        }
        editor?.addGutterItem(item: item)
        gutterItem = item
        setAccessibilityLabel("BlockReferenceNode")
        setAccessibilityRole(.textArea)

        open = false
    }

    static let blockLayerName = "blockLayerName"
    func createBlockLayerIfNeeded() -> Layer {
        guard let l = layers[Self.blockLayerName] else {
            let _blockLayer = CALayer()
            _blockLayer.cornerRadius = 6
            _blockLayer.zPosition = -1
            let blockLayer = Layer(name: Self.blockLayerName, layer: _blockLayer)
            addLayer(blockLayer)
            updateBackgroundColor(focused: isFocused, hover: hover)
            return blockLayer
        }

        return l
    }

    override func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
    }

    override func onFocus() {
        updateBackgroundColor(focused: true, hover: hover)
    }

    override func onUnfocus() {
        updateBackgroundColor(focused: false, hover: hover)
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
        let shift = CGFloat(0) //indent
        var f = contentsFrame.offsetBy(dx: shift, dy: 0)
        f.size.width -= shift
        f.size.height = idealSize.height - 5
        blockLayer.frame = f

        if let lockButton = layers[Self.lockButtonName] {
            lockButton.frame = NSRect(origin: CGPoint(x: f.maxX + 10, y: 0), size: lockButton.frame.size)
        }
        self.gutterItem?.updateFrameFromNode(self)
    }

    private func updateBackgroundColor(focused: Bool, hover: Bool) {
        var color: CGColor
        if focused {
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
        updateBackgroundColor(focused: isFocused, hover: hover)
    }

    private func openReferencedCard() {
        guard let noteid = self.displayedElement.note?.id else { return }
        self.editor?.openCard(noteid, self.displayedElement.id)
    }

    func showMenu(mouseInfo: MouseInfo) {
        let items = [
            ContextMenuItem(title: readOnly ? "Edit" : "Stop Editing", action: { [unowned self] in
                updateReadOnlyMode(!self.readOnly)
                guard let lockButton = self.layers[Self.lockButtonName] as? LockButton else { return }
                lockButton.locked = self.readOnly
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
