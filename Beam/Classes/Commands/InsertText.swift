//
//  InsertText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/02/2021.
//

import Foundation

class InsertText: TextEditorCommand {
    static let name: String = "InsertText"

    var text: BeamText
    var elementId: UUID
    var noteName: String
    var cursorPosition: Int
    var newCursorPosition: Int = 0
    var oldText: BeamText?

    init(text: BeamText, in elementId: UUID, of noteName: String, at cursorPosition: Int) {
        self.text = text
        self.elementId = elementId
        self.noteName = noteName
        self.cursorPosition = cursorPosition
        super.init(name: InsertText.name)
        saveOldText()
    }

    private func saveOldText() {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return }
        self.oldText = elementInstance.element.text
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }

        node.element.text.replaceSubrange(cursorPosition..<cursorPosition, with: text)
        newCursorPosition = text.text == "\n" ? node.position(after: cursorPosition) : cursorPosition + text.count
        context?.focus(widget: node, cursorPosition: newCursorPosition)
        context?.editor.detectFormatterType()
        context?.cancelSelection()
        return true
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root),
              let oldText = self.oldText else { return false }

        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        context?.focus(widget: node, cursorPosition: cursorPosition)
        context?.editor.detectFormatterType()
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == newCursorPosition,
              insertText.text.text != "\n",
              insertText.elementId == elementId,
              let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }

        self.text.append(insertText.text)
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)
        return true
    }
}
