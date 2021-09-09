//
//  InputText.swift
//  Beam
//
//  Created by Sebastien Metrot on 21/03/2021.
//

import Foundation
import BeamCore

class InputText: TextEditorCommand {
    static let name: String = "InputText"

    var insertText: InsertText
    var cancelSelection: CancelSelection
    var focusElement: FocusElement

    init(text: BeamText, in elementId: UUID, of noteId: UUID, at position: Int) {
        insertText = InsertText(text: text, in: elementId, of: noteId, at: position)
        cancelSelection = CancelSelection()
        focusElement = FocusElement(element: elementId, from: noteId, at: position + text.count)
        super.init(name: Self.name)
    }

    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }

    override func run(context: Widget?) -> Bool {
        let res = insertText.run(context: context)
        _ = cancelSelection.run(context: context)
        _ = focusElement.run(context: context)
        return res
    }

    override func undo(context: Widget?) -> Bool {
        let res = focusElement.undo(context: context)
        _ = cancelSelection.undo(context: context)
        _ = insertText.undo(context: context)
        return res
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let inputText = command as? InputText,
              inputText.insertText.elementId == insertText.elementId,
              inputText.insertText.noteId == insertText.noteId,
              inputText.insertText.cursorPosition == insertText.cursorPosition + insertText.text.count
        else { return false }

        return insertText.coalesce(command: inputText.insertText) && focusElement.coalesce(command: inputText.focusElement)
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func inputText(_ text: BeamText, in node: TextNode, at position: Int) -> Bool {
        guard let noteId = node.displayedElementNoteId else { return false }
        let cmd = InputText(text: text, in: node.displayedElementId, of: noteId, at: position)
        return run(command: cmd, on: node)
    }
}
