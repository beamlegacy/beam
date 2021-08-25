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

    init(parent: Widget, element: BeamElement) {
        super.init(parent: parent, element: element, nodeProvider: NodeProviderImpl(proxy: true))

        setupBlockReference()
    }

    init(editor: BeamTextEdit, element: BeamElement) {
        super.init(editor: editor, element: element, nodeProvider: NodeProviderImpl(proxy: true))

        setupBlockReference()
    }

    static let lockButtonName = "lock"

    func setupBlockReference() {
        readOnly = true
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
            self.readOnly = lock
        })
        addLayer(lockButton)

        _ = createCustomActionLayer(named: "visitSource", icons: ["field-card"], text: referencingNote.title, at: CGPoint(x: availableWidth + childInset + actionLayerPadding, y: firstLineBaseline)) {
            self.editor.openCard(referencingNote.id, self.displayedElement.id)
        }

        setAccessibilityLabel("BlockReferenceNode")
        setAccessibilityRole(.textArea)

        open = false
    }

    static let blockLayerName = "blockLayerName"
    func createBlockLayerIfNeeded() -> Layer {
        guard let l = layers[Self.blockLayerName] else {
            let _blockLayer = CALayer()
            _blockLayer.cornerRadius = 6
            _blockLayer.backgroundColor = BeamColor.AlphaGray.nsColor.withAlphaComponent(0.2).cgColor
            _blockLayer.zPosition = -1
            let blockLayer = Layer(name: Self.blockLayerName, layer: _blockLayer)
            addLayer(blockLayer)
            return blockLayer
        }

        return l
    }

    override func textPadding(elementKind: ElementKind) -> NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
    }

    override func onFocus() {
        createBlockLayerIfNeeded().layer.backgroundColor = BeamColor.Bluetiful.nsColor.withAlphaComponent(0.2).cgColor
    }

    override func onUnfocus() {
        createBlockLayerIfNeeded().layer.backgroundColor = BeamColor.AlphaGray.nsColor.withAlphaComponent(0.2).cgColor
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
        guard let lockButton = layers[Self.lockButtonName] else { return }
        lockButton.frame = NSRect(origin: CGPoint(x: availableWidth + 20, y: 0), size: lockButton.frame.size)

        let blockLayer = createBlockLayerIfNeeded()
        let shift = CGFloat(0) //indent
        var f = contentsFrame.offsetBy(dx: shift, dy: 0)
        f.size.width -= shift
        f.size.height = idealSize.height - 5
        blockLayer.frame = f

        if let actionLayer = layers["visitSource"] {
            actionLayer.frame = NSRect(origin: CGPoint(x: availableWidth + childInset + actionLayerPadding + 14, y: 0), size: actionLayer.frame.size)

        }
    }

    func showMenu(mouseInfo: MouseInfo) {
        let items = [
            ContextMenuItem(title: readOnly ? "Edit" : "Stop Editing", action: { [unowned self] in
                self.readOnly.toggle()
                guard let lockButton = self.layers[Self.lockButtonName] as? LockButton else { return }
                lockButton.locked = self.readOnly
            }),
            ContextMenuItem(title: "View Origin", action: {
                guard let noteid = self.displayedElement.note?.id else { return }
                self.editor.openCard(noteid, self.displayedElement.id)
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
