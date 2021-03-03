//
//  IncreaseIndentation.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class IncreaseIndentation: Command {
    var name: String = "IncreaseIndentation"

    var node: TextNode
    var element: BeamElement
    var previousParentElement: BeamElement?
    var indexInParent: Int?

    init(for node: TextNode) {
        self.node = node
        self.element = node.element
        self.indexInParent = node.indexInParent
    }

    func run() -> Bool {
        if let focussedNode = node.root?.focusedWidget as? TextNode, focussedNode !== self.node {
            self.node = focussedNode
        }
        if let parent = node.parent as? TextNode {
            self.previousParentElement = parent.element
        }
        guard let newParent = node.previousSibbling() as? TextNode else { return false }
        newParent.element.addChild(node.element)
        return true
    }

    func undo() -> Bool {
        guard let previousParentElement = self.previousParentElement,
              let indexInParent = self.indexInParent,
              let previousParent = node.root?.nodeFor(previousParentElement) else { return false }
        previousParent.element.insert(node.element, at: indexInParent)
        return true
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
