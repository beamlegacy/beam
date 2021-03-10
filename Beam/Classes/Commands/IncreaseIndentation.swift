//
//  IncreaseIndentation.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class IncreaseIndentation: TextEditorCommand {
    static let name = "IncreaseIndentation"
    var elementId: UUID
    var noteName: String
    var previousParentRef: NoteReference?
    var indexInParent: Int?

    init(for elementId: UUID, of noteName: String) {
        self.elementId = elementId
        self.noteName = noteName
        super.init(name: IncreaseIndentation.name)
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
            let elementInstance = getElement(for: noteName, and: elementId),
            let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }
//        let node = context?.nodeFor(elementInstance.element, withParent: root)
        indexInParent = node.indexInParent

        if let parent = node.parent as? TextNode {
            previousParentRef = NoteReference(noteName: noteName, elementID: parent.element.id)
        }
        guard let newParent = node.previousSibbling() as? TextNode else { return false }
        newParent.element.addChild(elementInstance.element)
        return true
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let previousParentRef = self.previousParentRef,
              let indexInParent = self.indexInParent,
              let previousElementInstance = getElement(for: previousParentRef.noteName, and: previousParentRef.elementID),
              let previousParent = context?.nodeFor(previousElementInstance.element, withParent: root) else { return false }

        previousParent.element.insert(elementInstance.element, at: indexInParent)
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }

}
