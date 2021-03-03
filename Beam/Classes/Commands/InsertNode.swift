//
//  InsertNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class InsertNode: Command {
    var name: String = "InsertNode"

    let cursorPosition: Int
    var node: TextNode
    var newNode: TextNode?
    var pos: Int

    init(in node: TextNode, with cursorPosition: Int, at pos: Int) {
        self.cursorPosition = cursorPosition
        self.node = node
        self.pos = pos + 1
    }

    func run() -> Bool {
        if let focussedNode = node.root?.focusedWidget as? TextNode, focussedNode !== self.node {
            self.node = focussedNode
        }
        let element = BeamElement()
        element.text = node.element.text.extract(range: self.cursorPosition..<node.element.text.count)
        node.text.removeLast(node.element.text.count - cursorPosition)

        var newNode: TextNode
        if let refNode = node as? LinkedReferenceNode,
           let proxyElement = refNode.element as? ProxyElement,
           let actualElement = proxyElement.parent,
           let actualParent = actualElement.parent {
            actualParent.addChild(element)
            let elements = actualElement.children
            for c in elements {
                element.addChild(c)
            }
            let newProxyElement = ProxyElement(for: element)
            newNode = node.nodeFor(newProxyElement)
        } else {
            newNode = node.nodeFor(element)
            let elements = node.element.children
            for c in elements {
                newNode.element.addChild(c)
            }
        }

        guard let result = node.parent?.insert(node: newNode, at: self.pos) else { return false }
        newNode.focus(cursorPosition: newNode.element.text.count)
        self.newNode = newNode
        return result
    }

    func undo() -> Bool {
        guard let newNode = self.newNode else { return false }

        if let prevVisible = newNode.previousVisible() as? TextNode {
            for c in newNode.element.children {
                prevVisible.element.addChild(c)
            }
        }
        newNode.delete()
        let remainingText = newNode.element.text.extract(range: 0..<newNode.text.count)
        node.text.append(remainingText)
        node.focus(cursorPosition: self.cursorPosition)
        return true
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
