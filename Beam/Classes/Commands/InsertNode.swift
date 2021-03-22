//
//  InsertNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class InsertNode: TextEditorCommand {
    static let name: String = "InsertNode"

    var elementId: UUID
    var noteTitle: String
    let cursorPosition: Int?
    var newElementId: UUID?
    var text: String?
    var data: Data?
    var insertAsChild: Bool

    init(in elementId: UUID, of noteTitle: String, with cursorPosition: Int?, asChild: Bool) {
        self.elementId = elementId
        self.noteTitle = noteTitle
        self.cursorPosition = cursorPosition
        self.insertAsChild = asChild
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return false }

        let element = decode(data: data) ?? BeamElement()
        if let cursorPosition = self.cursorPosition {
            element.text = elementInstance.element.text.extract(range: cursorPosition..<elementInstance.element.text.count)
            elementInstance.element.text.removeLast(elementInstance.element.text.count - cursorPosition)
        }

        self.newElementId = element.id

        if insertAsChild {
            elementInstance.element.insert(element, after: nil)
        } else {
            elementInstance.element.parent?.insert(element, after: elementInstance.element)
        }

        // UI Update
        guard let context = context,
              let root = context.root else { return true }

        guard let insertedNode = context.nodeFor(element) else { return true }
        insertedNode.parent?.open = true
        root.focus(widget: insertedNode)
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let newElementId = self.newElementId,
              let newElementInstance = getElement(for: noteTitle, and: newElementId),
              let elementInstance = getElement(for: noteTitle, and: elementId)
        else { return false }

        for c in newElementInstance.element.children {
            elementInstance.element.addChild(c)
        }
        if self.cursorPosition != nil {
            let remainingText = newElementInstance.element.text.extract(range: 0..<newElementInstance.element.text.count)
            elementInstance.element.text.append(remainingText)
        }

        data = encode(element: newElementInstance.element)

        newElementInstance.element.parent?.removeChild(newElementInstance.element)

        // UI Update
        guard  let context = context,
               let root = context.root,
               let node = context.nodeFor(elementInstance.element) else { return true }

        root.focus(widget: node, cursorPosition: self.cursorPosition)
        return true
    }
}
