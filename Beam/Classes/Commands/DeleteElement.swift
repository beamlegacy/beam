//
//  DeleteElement.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/03/2021.
//

import Foundation
import BeamCore

class DeleteElement: TextEditorCommand {
    static let name: String = "DeleteElement"

    var elementId: UUID
    var noteTitle: String
    var parentId: UUID?
    var indexInParent: Int?
    var data: Data?

    init(elementId: UUID, of noteTitle: String) {
        self.elementId = elementId
        self.noteTitle = noteTitle
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
              let parent = elementInstance.element.parent,
              let indexInParent = elementInstance.element.indexInParent
              else { return false }

        self.indexInParent = indexInParent
        parentId = parent.id
        data = encode(element: elementInstance.element)
        parent.removeChild(elementInstance.element)

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let data = self.data,
              let deletedElement = decode(data: data),
              let parentId = self.parentId,
              let indexInParent = indexInParent,
              let parentElementInstance = getElement(for: noteTitle, and: parentId) else { return false }

        parentElementInstance.element.insert(deletedElement, at: indexInParent)

        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func deleteElement(for node: TextNode) -> Bool {
        guard let title = node.elementNoteTitle else { return false }
        let cmd = DeleteElement(elementId: node.elementId, of: title)
        return run(command: cmd, on: node)
    }
}
