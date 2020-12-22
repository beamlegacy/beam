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
    var linkedReferenceNodes = [LinkedReferenceNode]()
//    var unlinkedReferenceNodes = [UnlinkedReferenceNode]()
    var linkedReferencesCancellable: Cancellable!

    override var parent: TextNode? {
        return editor.rootNode
    }

    override var root: TextRoot {
        return editor.rootNode
    }

    init(editor: BeamTextEdit, note: BeamNote) {
        super.init(editor: editor, element: BeamElement())
        self.note = note
        // Append the linked references and unlinked references nodes
        linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] linked in
            updateLinkedReferences()
        }

        updateLinkedReferences()
        text = BeamText(text: "LINKED REFERENCE SHIT")
        editor.layer?.addSublayer(layer)
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

    }
    override func updateRendering() {
        guard availableWidth > 0 else { return }

        if invalidatedTextRendering {
            textFrame = NSRect(x: 0, y: 0, width: availableWidth, height: 50)
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

    override func setLayout(_ frame: NSRect) {
        super.setLayout(frame)
        layer.backgroundColor = NSColor.red.cgColor
    }

}
