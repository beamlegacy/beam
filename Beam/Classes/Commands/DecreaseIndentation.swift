//
//  DecreaseIndentation.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class DecreaseIndentation: Command {
    var name: String = "DecreaseIndentation"

    var node: TextNode
    var previousParent: TextNode?
    var indexInParent: Int?

    init(for node: TextNode) {
        self.node = node
        self.previousParent = node.parent as? TextNode
        self.indexInParent = node.indexInParent
    }

    func run() -> Bool {
        guard let prevParent = self.previousParent,
              let newParent = prevParent.parent as? TextNode else { return false }
        newParent.element.insert(node.element, after: prevParent.element)
        return true
    }

    func undo() -> Bool {
        guard let prevParent = self.previousParent,
              let indexInParent = self.indexInParent else { return false }
        prevParent.element.insert(node.element, at: indexInParent)
        return true
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
