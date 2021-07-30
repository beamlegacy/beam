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
    var noteId: UUID
    var parentId: UUID?
    var indexInParent: Int?
    var data: Data?

    init(elementId: UUID, of noteId: UUID) {
        self.elementId = elementId
        self.noteId = noteId
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId),
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
              let parentElementInstance = getElement(for: noteId, and: parentId) else { return false }

        parentElementInstance.element.insert(deletedElement, at: indexInParent)

        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func deleteElement(for node: ElementNode) -> Bool {
        guard let noteId = node.displayedElementNoteId else { return false }
        let cmd = DeleteElement(elementId: node.displayedElementId, of: noteId)
        return run(command: cmd, on: node)
    }

    @discardableResult
    func deleteElement(for element: BeamElement, context: Widget? = nil) -> Bool {
        guard let noteId = element.note?.id else { return false }
        let cmd = DeleteElement(elementId: element.id, of: noteId)
        return run(command: cmd, on: context)
    }
}
