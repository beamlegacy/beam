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
    var noteTitle: String
    var newElementId: UUID
    var after: UUID?
    var data: Data?

    init(_ element: BeamElement, in elementId: UUID, of noteTitle: String, after: UUID?) {
        self.parentElementId = elementId
        self.noteTitle = noteTitle
        self.after = after
        self.newElementId = element.id
        super.init(name: Self.name)
        data = encode(element: element)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: parentElementId) else { return false }
        guard let element = decode(data: data) else { return false }

        var afterElement: BeamElement?
        if let after = after {
            afterElement = elementInstance.element.findElement(after)
        }

        elementInstance.element.insert(element, after: afterElement)
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let newElementInstance = getElement(for: noteTitle, and: newElementId),
              let elementInstance = getElement(for: noteTitle, and: parentElementId)
        else { return false }

        elementInstance.element.removeChild(newElementInstance.element)
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func insertElement(_ element: BeamElement, in node: TextNode, after: TextNode?) -> Bool {
        guard let title = node.elementNoteTitle else { return false }
        let cmd = InsertElement(element, in: node.elementId, of: title, after: after?.elementId)
        return run(command: cmd, on: node)
    }
}
