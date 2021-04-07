//
//  ReparentElement.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation
import BeamCore

class ReparentElement: TextEditorCommand {
    static let name = "ReparentElement"
    var elementId: UUID
    var newParentId: UUID
    var newIndexInParent: Int
    var noteTitle: String
    var previousParentId: UUID?
    var previousIndexInParent: Int?

    init(_ elementId: UUID, of noteTitle: String, to newParent: UUID, atIndex newIndexInParent: Int) {
        self.elementId = elementId
        self.newParentId = newParent
        self.newIndexInParent = newIndexInParent
        self.noteTitle = noteTitle

        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
            let newParentInstance = getElement(for: noteTitle, and: newParentId),
            let previousParent = elementInstance.element.parent
        else { return false }

        // Bread Crumbs are a bitch
        if let breadCrumb = context?.parent as? BreadCrumb, let node = context?.nodeFor(elementInstance.element) {
            breadCrumb.removeChild(node)
        }

        previousParentId = previousParent.id
        previousIndexInParent = elementInstance.element.indexInParent
        newParentInstance.element.insert(elementInstance.element, at: newIndexInParent)

        if let newParentNode = context?.nodeFor(newParentInstance.element) {
            newParentNode.open = true
        }

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
              let previousParentId = self.previousParentId,
              let previousIndexInParent = self.previousIndexInParent,
              let previousElementInstance = getElement(for: noteTitle, and: previousParentId)
        else { return false }

        // Bread Crumbs are a bitch
        if let breadCrumb = context?.parent as? BreadCrumb, let node = context?.nodeFor(elementInstance.element) {
            breadCrumb.removeChild(node)
        }

        previousElementInstance.element.insert(elementInstance.element, at: previousIndexInParent)

        if let newParentNode = context?.nodeFor(previousElementInstance.element) {
            newParentNode.open = true
        }

        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func reparentElement(_ node: TextNode, to parent: TextNode, atIndex newIndex: Int) -> Bool {
        // make sure all elements are in the name note
        guard let title = node.elementNoteTitle ?? parent.elementNoteTitle
        else { return false }
        let cmd = ReparentElement(node.elementId, of: title, to: parent.elementId, atIndex: newIndex)
        return run(command: cmd, on: parent)
    }

    @discardableResult
    func reparentElement(_ element: BeamElement, to parent: BeamElement, atIndex newIndex: Int) -> Bool {
        // make sure all elements are in the name note
        guard let title = element.note?.title ?? parent.note?.title else { return false }
        let cmd = ReparentElement(element.id, of: title, to: parent.id, atIndex: newIndex)
        return run(command: cmd, on: nil)
    }
}
