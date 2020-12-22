//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine

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

        // Append the linked references and unlinked references nodes
        linkedReferencesCancellable = note.$linkedReferences.sink { [unowned self] linked in
            self.linkedReferenceNodes = linked.map { noteReference -> LinkedReferenceNode in
                guard let referencingNote = BeamNote.fetch(DocumentManager(), title: noteReference.noteName) else { fatalError() }
                guard let referencingElement = referencingNote.findElement(noteReference.elementID) else {
                    fatalError()
                }
                return LinkedReferenceNode(editor: editor, element: referencingElement)
            }
        }

        text = BeamText(text: "LINKED REFERENCE SHIT")
    }
}
