//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine
import AppKit

class LinksSection: TextRoot {
    var linkedReferenceNodes = [LinkedReferenceNode]() {
        didSet {
            invalidateLayout()
        }
    }
//    var unlinkedReferenceNodes = [UnlinkedReferenceNode]()
    var linkedReferencesCancellable: Cancellable!

    override var parent: TextNode? {
        return editor.rootNode
    }

    override var children: [TextNode] {
        return linkedReferenceNodes
    }

    override var root: TextRoot {
        return editor.rootNode
    }

    init(editor: BeamTextEdit, note: BeamNote) {
        super.init(editor: editor, element: BeamElement())
        self.note = note
        // Append the linked references and unlinked references nodes
        linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] _ in
            updateLinkedReferences()
        }

        updateLinkedReferences()
        text = BeamText(text: "Link")
        editor.layer?.addSublayer(layer)
//        layer.backgroundColor = NSColor.red.cgColor
    }

    func updateLinkedReferences() {
        guard let note = note else { return }
        self.linkedReferenceNodes = note.linkedReferences.map { noteReference -> LinkedReferenceNode in
            guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { fatalError() }
            guard let referencingElement = referencingNote.findElement(noteReference.elementID) else {
                fatalError()
            }
            return LinkedReferenceNode(editor: editor, element: referencingElement)
        }

        selfVisible = !linkedReferenceNodes.isEmpty
    }

    override func setLayout(_ frame: NSRect) {
        super.setLayout(frame)
    }

    public override  func draw(in context: CGContext) {
//        context.translateBy(x: indent, y: 0)
//
//        drawDebug(in: context)
//
//        if selfVisible {
//            // print("Draw text \(frame))")
//
//            context.saveGState(); defer { context.restoreGState() }
//
//            context.textMatrix = CGAffineTransform.identity
//            context.translateBy(x: 0, y: firstLineBaseline)
//
//            layout?.draw(context)
//        }
        super.draw(in: context)

        context.saveGState()

//        let c = NSColor.green.cgColor
//        context.setStrokeColor(c)
//        context.stroke(textFrame)
//
//        context.setFillColor(c.copy(alpha: 0.4)!)
//        context.fill(textFrame)

        context.restoreGState()
    }
}
