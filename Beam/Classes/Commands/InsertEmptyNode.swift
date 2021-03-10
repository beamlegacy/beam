//
//  InsertEmptyNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/02/2021.
//

import Foundation

class InsertEmptyNode: TextEditorCommand {
    static let name: String = "InsertEmptyNode"

    var parentElementId: UUID
    var noteName: String
    let index: Int
    var newElementId: UUID?
    var data: Data?

    init(with parentElementId: UUID, of noteName: String, at index: Int = 0) {
        self.parentElementId = parentElementId
        self.noteName = noteName
        self.index = index
        super.init(name: InsertEmptyNode.name)
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
              let parentElementInstance = getElement(for: noteName, and: parentElementId),
              let node = context?.nodeFor(parentElementInstance.element, withParent: root) else { return false }

        let element = decode(data: data) ?? BeamElement()
        guard let newNode = context?.nodeFor(element, withParent: root) else { return false }
        let result = node.insert(node: newNode, at: index)
        self.newElementId = element.id
        context?.focus(widget: newNode)
        return result
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let newElementId = newElementId,
              let newElementInstance = getElement(for: noteName, and: newElementId),
              let node = context?.nodeFor(newElementInstance.element, withParent: root),
              let parentElementInstance = getElement(for: noteName, and: parentElementId),
              let parentNode = context?.nodeFor(parentElementInstance.element, withParent: root) else { return false }

        for c in node.element.children {
            parentNode.element.addChild(c)
        }

        data = encode(element: newElementInstance.element)
        node.delete()
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }
}
