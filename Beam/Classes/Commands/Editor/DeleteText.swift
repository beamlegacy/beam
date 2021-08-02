//
//  DeleteText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 18/02/2021.
//

import Foundation
import BeamCore

class DeleteText: TextEditorCommand {
    static let name: String = "DeleteText"

    var elementId: UUID
    var noteId: UUID
    var range: Range<Int>
    var oldText = BeamText()

    var cancelSelection: CancelSelection
    var focusElement: FocusElement

    init(in elementId: UUID, of noteId: UUID, for range: Range<Int>) {
        self.elementId = elementId
        self.noteId = noteId
        self.range = range

        cancelSelection = CancelSelection()
        focusElement = FocusElement(element: elementId, from: noteId, at: range.lowerBound)

        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId) else { return false }

        let cursor = (context as? TextNode)?.cursorPosition
        self.oldText = elementInstance.element.text.extract(range: range)
        elementInstance.element.text.remove(count: range.count, at: range.lowerBound)

        _ = cancelSelection.run(context: context)
        _ = focusElement.run(context: context)
        // we need to cheat, this is ugly but the previous operations may have changed the original position of the cursor
        if let cursor = cursor {
            cancelSelection.oldCursorPosition = cursor
            focusElement.oldCursorPosition = cursor
        }

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId)
        else { return false }

        elementInstance.element.text.insert(oldText, at: range.lowerBound)

        _ = focusElement.undo(context: context)
        _ = cancelSelection.undo(context: context)

        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let deleteText = command as? DeleteText,
              deleteText.elementId == elementId,
              deleteText.noteId == noteId,
              (deleteText.range.upperBound == range.lowerBound || deleteText.range.lowerBound == range.lowerBound)
        else { return false }

        if range.lowerBound == deleteText.range.lowerBound {
            self.range = range.lowerBound ..< (range.lowerBound + range.count + deleteText.range.count)
            oldText.append(deleteText.oldText)
        } else {
            self.range = deleteText.range.lowerBound ..< (range.lowerBound + range.count + deleteText.range.count)
            oldText.insert(deleteText.oldText, at: 0)
        }
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func deleteText(in node: TextNode, for range: Range<Int>) -> Bool {
        guard let noteId = node.displayedElementNoteId else { return false }
        let cmd = DeleteText(in: node.displayedElementId, of: noteId, for: range)
        return run(command: cmd, on: node)
    }
}
