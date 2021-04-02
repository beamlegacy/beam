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
    var noteTitle: String
    var range: Range<Int>
    var oldText = BeamText()

    var cancelSelection: CancelSelection
    var focusElement: FocusElement

    init(in elementId: UUID, of noteTitle: String, for range: Range<Int>) {
        self.elementId = elementId
        self.noteTitle = noteTitle
        self.range = range

        cancelSelection = CancelSelection()
        focusElement = FocusElement(element: elementId, from: noteTitle, at: range.lowerBound)

        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId) else { return false }

        self.oldText = elementInstance.element.text.extract(range: range)
        elementInstance.element.text.remove(count: range.count, at: range.lowerBound)

        _ = cancelSelection.run(context: context)
        _ = focusElement.run(context: context)

        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId)
        else { return false }

        elementInstance.element.text.insert(oldText, at: range.lowerBound)

        _ = focusElement.undo(context: context)
        _ = cancelSelection.undo(context: context)

        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let deleteText = command as? DeleteText,
              deleteText.elementId == elementId,
              deleteText.noteTitle == noteTitle,
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
        guard let title = node.elementNoteTitle else { return false }
        let cmd = DeleteText(in: node.elementId, of: title, for: range)
        return run(command: cmd, on: node)
    }
}
