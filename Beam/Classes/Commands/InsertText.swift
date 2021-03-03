//
//  InsertText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 17/02/2021.
//

import Foundation

class InsertText: Command {
    var name: String = "InsertText"

    var oldText: BeamText
    var text: String
    var node: TextNode
    var cursorPosition: Int
    var newCursorPosition: Int = 0

    init(text: String, in node: TextNode, at cursorPosition: Int) {
        self.text = text
        self.node = node
        self.cursorPosition = cursorPosition
        self.oldText = node.element.text
    }

    func run() -> Bool {
        if let focussedNode = node.root?.focusedWidget as? TextNode, focussedNode !== self.node {
            self.node = focussedNode
        }
        node.element.text.insert(text, at: cursorPosition)
        newCursorPosition = text == "\n" ? node.position(after: cursorPosition) : cursorPosition + text.count
        node.focus(cursorPosition: newCursorPosition)
        node.root?.cancelSelection()
        return true
    }

    func undo() -> Bool {
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        node.focus(cursorPosition: cursorPosition)
        return true
    }

    func coalesce(command: Command) -> Bool {
        guard let insertText = command as? InsertText,
              insertText.cursorPosition == newCursorPosition,
              insertText.text != "\n" else { return false }

        self.text = text + insertText.text
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        return true
    }

}
