//
//  ReplaceText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class ReplaceText: TextEditorCommand {
    static let name: String = "ReplaceText"

    var elementId: UUID
    var noteName: String
    var range: Range<Int>
    var cursorPosition: Int
    var text: BeamText
    var oldText: BeamText?

    init(in elementId: UUID, of noteName: String, for range: Range<Int>, at cursorPosition: Int, with text: BeamText) {
        self.elementId = elementId
        self.noteName = noteName
        self.range = range
        self.cursorPosition = cursorPosition
        self.text = text
        super.init(name: ReplaceText.name)
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

        node.element.text.replaceSubrange(range, with: text)
        cursorPosition = range.lowerBound + text.count
        context?.focus(widget: node, cursorPosition: cursorPosition)
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
        context?.state.selectedTextRange = range
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == cursorPosition,
              insertText.text.text != "\n",
              let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }

        self.text.append(insertText.text)
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)
        return true
    }
}
