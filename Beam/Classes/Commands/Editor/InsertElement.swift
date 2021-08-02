//
//  InsertNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation
import BeamCore

class InsertElement: TextEditorCommand {
    static let name: String = "InsertNode"

    var parentElementId: UUID
    var noteId: UUID
    var newElementId: UUID
    var after: UUID?
    var data: Data?

    init(_ element: BeamElement, in elementId: UUID, of noteId: UUID, after: UUID?) {
        self.parentElementId = elementId
        self.noteId = noteId
        self.after = after
        self.newElementId = element.id
        super.init(name: Self.name)
        data = encode(element: element)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: parentElementId) else { return false }
        guard let element = decode(data: data) else { return false }

        var afterElement: BeamElement?
        if let after = after {
            afterElement = elementInstance.element.findElement(after)
        }

        elementInstance.element.insert(element, after: afterElement)
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let newElementInstance = getElement(for: noteId, and: newElementId),
              let elementInstance = getElement(for: noteId, and: parentElementId)
        else { return false }

        elementInstance.element.removeChild(newElementInstance.element)
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func insertElement(_ element: BeamElement, inNode: ElementNode, afterNode: ElementNode?) -> Bool {
        guard let noteId = inNode.displayedElementNoteId else { return false }
        let cmd = InsertElement(element, in: inNode.displayedElementId, of: noteId, after: afterNode?.displayedElementId)
        return run(command: cmd, on: inNode)
    }

    @discardableResult
    func insertElement(_ element: BeamElement, inNode: ElementNode, afterElement: BeamElement?) -> Bool {
        guard let noteId = inNode.displayedElementNoteId else { return false }
        let cmd = InsertElement(element, in: inNode.displayedElementId, of: noteId, after: afterElement?.id)
        return run(command: cmd, on: inNode)
    }

    @discardableResult
    func insertElement(_ element: BeamElement, inElement: BeamElement, afterElement: BeamElement?) -> Bool {
        guard let noteId = inElement.note?.id else { return false }
        let cmd = InsertElement(element, in: inElement.id, of: noteId, after: afterElement?.id)
        return run(command: cmd, on: nil)
    }
}
