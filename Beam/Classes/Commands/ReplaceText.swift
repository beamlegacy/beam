//
//  ReplaceText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class ReplaceText: Command {
    var name: String = "ReplaceText"

    var oldText: BeamText
    var node: TextNode
    var range: Range<Int>
    var cursorPosition: Int
    var text: String

    init(in node: TextNode, for range: Range<Int>, at cursorPosition: Int, with text: String) {
        self.node = node
        self.range = range
        self.cursorPosition = cursorPosition
        self.text = text
        self.oldText = node.element.text
    }

    func run() -> Bool {
        node.element.text.replaceSubrange(range, with: text)
        cursorPosition = range.lowerBound + text.count
        node.root?.cursorPosition = cursorPosition
        node.root?.focussedWidget = node
        node.root?.cancelSelection()
        return true
    }

    func undo() -> Bool {
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        node.root?.focussedWidget = node
        node.root?.selectedTextRange = range
        node.root?.cursorPosition = range.upperBound
        return true
    }

    func coalesce(command: Command) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == cursorPosition,
              insertText.text != "\n" else { return false }

        self.text = text + insertText.text
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        return true
    }
}
