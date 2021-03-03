//
//  InsertEmptyNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/02/2021.
//

import Foundation

class InsertEmptyNode: Command {
    var name: String = "InsertEmptyNode"

    let parent: TextNode
    let index: Int
    var newNode: TextNode?

    init(with parent: TextNode, at index: Int = 0) {
        self.parent = parent
        self.index = index
    }

    func run() -> Bool {
        let element = BeamElement()
        parent.element.insert(element, at: index)
        let newNode = parent.root?.nodeFor(element)
        newNode?.focus()
        self.newNode = newNode
        return true
    }

    func undo() -> Bool {
        guard let newNode = self.newNode else { return false }

        for c in newNode.element.children {
            parent.element.addChild(c)
        }
        newNode.delete()
        return true
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
