//
//  InsertText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/02/2021.
//

import Foundation
import BeamCore

class InsertText: TextEditorCommand {
    static let name: String = "InsertText"

    var text: BeamText
    var elementId: UUID
    var noteId: UUID
    var cursorPosition: Int
    var oldText: BeamText?

    init(text: BeamText, in elementId: UUID, of noteId: UUID, at cursorPosition: Int) {
        self.text = text
        self.elementId = elementId
        self.noteId = noteId
        self.cursorPosition = cursorPosition
        super.init(name: Self.name)
        saveOldText()
    }

    private func saveOldText() {
        guard let elementInstance = getElement(for: noteId, and: elementId) else { return }
        self.oldText = elementInstance.element.text
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId) else { return false }
        elementInstance.element.text.replaceSubrange(cursorPosition..<cursorPosition, with: text)

        // Update the UI if possible:
        guard let context = context,
              let root = context.root,
              context.nodeFor(elementInstance.element) != nil
        else { return true }
        root.editor?.detectTextFormatterType()
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId),
              let oldText = self.oldText else { return false }
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)

        // Update the UI if possible:
        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element) else { return true }

        root.focus(widget: node, position: cursorPosition)
        root.editor?.detectTextFormatterType()
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == cursorPosition + text.count,
              insertText.text.text != "\n",
              insertText.elementId == elementId,
              insertText.noteId == noteId
              else { return false }

        self.text.append(insertText.text)
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func insertText(_ text: BeamText, in node: TextNode, at cursorPosition: Int) -> Bool {
        guard let id = node.displayedElementNoteId else { return false }
        let cmd = InsertText(text: text, in: node.displayedElementId, of: id, at: cursorPosition)
        return run(command: cmd, on: node)
    }
}
