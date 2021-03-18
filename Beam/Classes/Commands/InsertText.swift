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

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }
        elementInstance.element.text.replaceSubrange(cursorPosition..<cursorPosition, with: text)

        // Update the UI if possible:
        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element)
        else { return true }
        newCursorPosition = text.text == "\n" ? node.position(after: cursorPosition) : cursorPosition + text.count
        root.focus(widget: node, cursorPosition: newCursorPosition)
        root.editor.detectFormatterType()
        root.cancelSelection()
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)

        // Update the UI if possible:
        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element) else { return true }

        root.focus(widget: node, cursorPosition: cursorPosition)
        root.editor.detectFormatterType()
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == newCursorPosition,
              insertText.text.text != "\n",
              insertText.elementId == elementId,
              insertText.noteName == noteName,
              let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }

        self.text.append(insertText.text)
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)
        return true
    }
}
