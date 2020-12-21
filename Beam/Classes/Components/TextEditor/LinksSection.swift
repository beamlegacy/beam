//
//  LinksSection.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/12/2020.
//

import Foundation
import Combine

class LinksSection: TextNode {
    var note: BeamNote
    var linkedReferenceNodes = [LinkedReferenceNode]()
//    var unlinkedReferenceNodes = [UnlinkedReferenceNode]()
    var linkedReferencesCancellable: Cancellable!

    init(editor: BeamTextEdit, note: BeamNote) {
        self.note = note

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
    }
}
