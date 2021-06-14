//
//  ReplaceText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation
import BeamCore

class ReplaceText: TextEditorCommand {
    static let name: String = "ReplaceText"

    var elementId: UUID
    var noteTitle: String
    var range: Range<Int>
    var text: BeamText
    var oldText: BeamText?

    init(in elementId: UUID, of noteTitle: String, for range: Range<Int>, with text: BeamText) {
        self.elementId = elementId
        self.noteTitle = noteTitle
        self.range = range
        self.text = text
        super.init(name: Self.name)
        saveOldText()
    }

    private func saveOldText() {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return }
        self.oldText = elementInstance.element.text
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return false }
        elementInstance.element.text.replaceSubrange(range, with: text)
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
              let oldText = self.oldText else { return false }
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)

        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.text.text != "\n",
              insertText.noteTitle == noteTitle,
              insertText.elementId == elementId
        else { return false }

        self.text.append(insertText.text)
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func replaceText(in node: TextNode, for range: Range<Int>, with text: BeamText) -> Bool {
        guard let title = node.displayedElementNoteTitle else { return false }
        let cmd = ReplaceText(in: node.displayedElementId, of: title, for: range, with: text)
        return run(command: cmd, on: node)
    }
}
