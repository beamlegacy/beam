//
//  InsertEmptyNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/02/2021.
//

import Foundation
import BeamCore

class InsertEmptyNode: TextEditorCommand {
    static let name: String = "InsertEmptyNode"

    var parentElementId: UUID
    var noteTitle: String
    let index: Int
    var newElementId: UUID?
    var data: Data?

    init(with parentElementId: UUID, of noteTitle: String, at index: Int = 0) {
        self.parentElementId = parentElementId
        self.noteTitle = noteTitle
        self.index = index
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let context = context,
              let root = context.root,
              let parentElementInstance = getElement(for: noteTitle, and: parentElementId) else { return false }

        let element = decode(data: data) ?? BeamElement()
        parentElementInstance.element.insert(element, at: index)
        self.newElementId = element.id
        // UI Update
        guard let newNode = context.nodeFor(element) else { return true }
        root.focus(widget: newNode)
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let newElementId = newElementId,
              let newElementInstance = getElement(for: noteTitle, and: newElementId),
              let parentElementInstance = getElement(for: noteTitle, and: parentElementId) else { return false }

        for c in newElementInstance.element.children {
            parentElementInstance.element.addChild(c)
        }

        data = encode(element: newElementInstance.element)
        newElementInstance.element.parent?.removeChild(newElementInstance.element)
        return true
    }
}
