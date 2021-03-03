//
//  DeleteText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 18/02/2021.
//

import Foundation

class DeleteText: Command {
    var name: String = "DeleteText"

    var oldText: BeamText
    var node: TextNode
    var cursorPosition: Int
    var range: Range<Int>
    let backward: Bool

    init(in node: TextNode, at cursorPosition: Int, for range: Range<Int>, backward: Bool = true) {
        self.node = node
        self.cursorPosition = cursorPosition
        self.range = range
        self.oldText = node.element.text
        self.backward = backward
    }

    func run() -> Bool {
        var newPos: Int
        if backward {
            newPos = node.element.text.position(before: range.lowerBound)
        } else {
            newPos = range.lowerBound
        }
        let count = range.count == 0 ? 1 : range.count + 1
        node.element.text.remove(count: count, at: newPos)
        node.root?.focussedWidget = node
        node.root?.cursorPosition = newPos
        node.root?.cancelSelection()
        return true
    }

    func undo() -> Bool {
        if let focussedNode = node.root?.focussedWidget as? TextNode, focussedNode !== self.node {
            self.node = focussedNode
        }
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        node.root?.focussedWidget = node
        node.root?.cursorPosition = range.upperBound
        return true
    }

    func coalesce(command: Command) -> Bool {
        guard let deleteText = command as? DeleteText,
              deleteText.backward == backward else { return false }

        if backward && deleteText.range.lowerBound == range.lowerBound - 1 {
            self.range = deleteText.range.lowerBound..<range.upperBound
        } else if range.lowerBound == deleteText.range.lowerBound {
            self.range = range.lowerBound..<range.upperBound + 1
        }
        node.element.text.replaceSubrange(node.element.text.wholeRange, with: oldText)
        return true
    }
}
