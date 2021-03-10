//
//  DeleteText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 18/02/2021.
//

import Foundation

class DeleteText: TextEditorCommand {
    static let name: String = "DeleteText"

    var elementId: UUID
    var noteName: String
    var cursorPosition: Int
    var range: Range<Int>
    let backward: Bool
    var oldText: BeamText?

    init(in elementId: UUID, of noteName: String, at cursorPosition: Int, for range: Range<Int>, backward: Bool = true) {
        self.elementId = elementId
        self.noteName = noteName
        self.cursorPosition = cursorPosition
        self.range = range
        self.backward = backward
        super.init(name: DeleteText.name)
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

        var newPos: Int
        if backward {
            newPos = node.element.text.position(before: range.lowerBound)
        } else {
            newPos = range.lowerBound
        }
        let count = range.count == 0 ? 1 : range.count + 1
        node.element.text.remove(count: count, at: newPos)
        context?.focus(widget: node, cursorPosition: newPos)
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
        context?.focus(widget: node, cursorPosition: range.upperBound)
        context?.state.selectedTextRange = range.lowerBound - 1..<range.upperBound
        context?.editor.detectFormatterType()
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        guard let deleteText = command as? DeleteText,
              deleteText.backward == backward,
              deleteText.elementId == elementId,
              let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }

        if backward && deleteText.range.lowerBound == range.lowerBound - 1 {
            self.range = deleteText.range.lowerBound..<range.upperBound
        } else if range.lowerBound == deleteText.range.lowerBound {
            self.range = range.lowerBound..<range.upperBound + 1
        }
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)
        return true
    }
}
