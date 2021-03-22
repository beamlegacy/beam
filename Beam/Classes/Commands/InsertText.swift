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
    var noteTitle: String
    var cursorPosition: Int
    var oldText: BeamText?

    init(text: BeamText, in elementId: UUID, of noteTitle: String, at cursorPosition: Int) {
        self.text = text
        self.elementId = elementId
        self.noteTitle = noteTitle
        self.cursorPosition = cursorPosition
        super.init(name: Self.name)
        saveOldText()
    }

    private func saveOldText() {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return }
        self.oldText = elementInstance.element.text
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return false }
        elementInstance.element.text.replaceSubrange(cursorPosition..<cursorPosition, with: text)

        // Update the UI if possible:
        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element)
        else { return true }
        root.editor.detectFormatterType()
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
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
              insertText.cursorPosition == cursorPosition + text.count,
              insertText.text.text != "\n",
              insertText.elementId == elementId,
              insertText.noteTitle == noteTitle
              else { return false }

        self.text.append(insertText.text)
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func insertText(_ text: BeamText, in node: TextNode, at position: Int) -> Bool {
        guard let title = node.elementNoteTitle else { return false }
        let cmd = InsertText(text: text, in: node.elementId, of: title, at: position)
        return run(command: cmd, on: node)
    }
}
