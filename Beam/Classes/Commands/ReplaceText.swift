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

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }
        elementInstance.element.text.replaceSubrange(range, with: text)

        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element) else { return false }
        cursorPosition = range.lowerBound + text.count
        root.focus(widget: node, cursorPosition: cursorPosition)
        root.cancelSelection()
        return true
    }

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)

        guard let context = context,
              let root = context.root,
              let node = context.nodeFor(elementInstance.element) else { return false }

        root.focus(widget: node, cursorPosition: range.upperBound)
        root.state.selectedTextRange = range
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == cursorPosition,
              insertText.text.text != "\n",
              insertText.noteName == noteName,
              insertText.elementId == elementId,
              let elementInstance = getElement(for: noteName, and: elementId),
              let oldText = self.oldText else { return false }

        self.text.append(insertText.text)
        elementInstance.element.text.replaceSubrange(elementInstance.element.text.wholeRange, with: oldText)
        return true
    }
}
