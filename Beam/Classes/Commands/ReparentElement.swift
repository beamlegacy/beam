//
//  ReparentElement.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class ReparentElement: TextEditorCommand {
    static let name = "ReparentElement"
    var elementId: UUID
    var newParentId: UUID
    var newIndexInParent: Int
    var noteName: String
    var previousParentId: UUID?
    var previousIndexInParent: Int?

    init(for elementId: UUID, of noteName: String, to newParent: UUID, atIndex newIndexInParent: Int) {
        self.elementId = elementId
        self.newParentId = newParent
        self.newIndexInParent = newIndexInParent
        self.noteName = noteName

        super.init(name: ReparentElement.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId),
            let newParentInstance = getElement(for: noteName, and: newParentId),
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
        guard let elementInstance = getElement(for: noteName, and: elementId),
              let previousParentId = self.previousParentId,
              let indexInParent = self.previousIndexInParent,
              let previousElementInstance = getElement(for: noteName, and: previousParentId)
        else { return false }

        // Bread Crumbs are a bitch
        if let breadCrumb = context?.parent as? BreadCrumb, let node = context?.nodeFor(elementInstance.element) {
            breadCrumb.removeChild(node)
        }

        previousElementInstance.element.insert(elementInstance.element, at: indexInParent)

        if let newParentNode = context?.nodeFor(previousElementInstance.element) {
            newParentNode.open = true
        }

        return true
    }
}
