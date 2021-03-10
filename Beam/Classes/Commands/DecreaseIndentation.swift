//
//  DecreaseIndentation.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class DecreaseIndentation: TextEditorCommand {
    static let name: String = "DecreaseIndentation"
    var elementId: UUID
    var noteName: String
    var previousParentRef: NoteReference?
    var indexInParent: Int?

    init(for elementId: UUID, of noteName: String) {
        self.elementId = elementId
        self.noteName = noteName
        super.init(name: DecreaseIndentation.name)
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root),
              let prevParent = node.parent as? TextNode,
              let newParent = prevParent.parent as? TextNode else { return false }

        previousParentRef = NoteReference(noteName: noteName, elementID: prevParent.element.id)
        indexInParent = node.indexInParent
        newParent.element.insert(elementInstance.element, after: prevParent.element)
        return true
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let previousParentRef = self.previousParentRef,
              let newParentElementInstance = getElement(for: noteName, and: previousParentRef.elementID),
              let newParentNode = context?.nodeFor(newParentElementInstance.element, withParent: root) else {
            return false
        }
        newParentNode.element.insert(elementInstance.element, after: newParentElementInstance.element)
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }
}
