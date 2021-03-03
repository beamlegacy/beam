//
//  DeleteNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

enum DeleteNodeMode {
    case backward
    case forward
    case selected
}

class DeleteNode: Command {
    var name: String = "DeleteNode"

    var node: TextNode
    var element: BeamElement
    let deleteNodeMode: DeleteNodeMode
    var lastElementVisible: BeamElement?
    var textRoot: TextRoot?
    var isIndented: Bool = false
    var indexInParent: Int?

    init(node: TextNode, deleteNodeMode: DeleteNodeMode) {
        self.node = node
        self.element = node.element
        self.textRoot = node.root
        self.deleteNodeMode = deleteNodeMode
    }

    func run() -> Bool {
        switch deleteNodeMode {
        case .backward:
            return runBackward()
        case .forward:
            return runForward()
        case .selected:
            return runDelete()
        }
    }

    private func isIntended(node: TextNode) {
        guard let parent = node.parent as? TextNode,
              parent.parent as? TextNode != nil else { return }
        self.isIndented = true
        self.indexInParent = node.indexInParent
    }

    private func runBackward() -> Bool {
        guard let prevVisible = node.previousVisible() as? TextNode else { return false }
        isIntended(node: node)
        self.lastElementVisible = prevVisible.element

        for c in node.element.children {
            prevVisible.element.addChild(c)
        }
        node.delete()

        prevVisible.element.text.append(element.text)
        prevVisible.root?.focussedWidget = prevVisible
        prevVisible.root?.cursorPosition = prevVisible.element.text.count
        prevVisible.root?.cancelSelection()
        return true
    }

    private func runForward() -> Bool {
        guard let nextVisible = node.nextVisible() as? TextNode else { return false }
        isIntended(node: nextVisible)

        for c in nextVisible.element.children {
            node.element.addChild(c)
        }
        self.element = nextVisible.element
        node.element.text.append(nextVisible.element.text)
        self.lastElementVisible = node.element

        nextVisible.delete()

        node.root?.cancelSelection()
        return true
    }

    private func runDelete() -> Bool {
        var prevVisibleNode: TextNode
        isIntended(node: node)
        if let prevVisible = node.previousSibbling() as? TextNode, isIndented {
            prevVisibleNode = prevVisible
        } else if let prevVisible = node.previousVisible() as? TextNode {
            prevVisibleNode = prevVisible
        } else if let prevVisible = node.root {
            prevVisibleNode = prevVisible
        } else {
            return false
        }
        self.lastElementVisible = prevVisibleNode.element

        for c in node.element.children {
            prevVisibleNode.element.addChild(c)
        }
        node.delete()
        prevVisibleNode.root?.cancelNodeSelection()
        return true
    }

    func undo() -> Bool {
        switch deleteNodeMode {
        case .backward:
            return undoBackward()
        case .forward:
            return undoForward()
        case .selected:
            return undoDelete()
        }
    }

    private func undoBackward() -> Bool {
        guard let root = self.textRoot,
              let lastElementVisible = self.lastElementVisible else { return false }

        let newLastNode = root.nodeFor(lastElementVisible)
        newLastNode.element.text.removeLast(element.text.count)

        let newNode = newLastNode.nodeFor(element)
        for c in newLastNode.element.children {
            newNode.element.addChild(c)
        }
        if let indexInParent = self.indexInParent, isIndented {
            newLastNode.element.insert(newNode.element, at: indexInParent)
        } else {
            guard newLastNode.parent?.insert(node: newNode, after: newLastNode) != nil else { return false }
        }
        root.focussedWidget = newNode
        root.cursorPosition = 0
        self.node = newNode
        return true
    }

    private func undoForward() -> Bool {
        guard let root = self.textRoot,
              let lastElementVisible = self.lastElementVisible else { return false }

        let currentNode = root.nodeFor(lastElementVisible)
        currentNode.text.removeLast(self.element.text.count)
        let newNode = root.nodeFor(self.element)
        for c in node.element.children {
            newNode.element.addChild(c)
        }
        if let indexInParent = self.indexInParent, isIndented {
            currentNode.element.insert(newNode.element, at: indexInParent)
        } else {
            guard currentNode.parent?.insert(node: newNode, after: currentNode) != nil else { return false }
        }
        return true
    }

    private func undoDelete() -> Bool {
        guard let root = self.textRoot,
              let lastElementVisible = self.lastElementVisible else { return false }

        let prevVisible = root.nodeFor(lastElementVisible)

        if prevVisible == root {
            prevVisible.element.insert(self.element, at: 0)
        }

        let newNode = prevVisible.nodeFor(element)
        if prevVisible != node.root {
            for c in prevVisible.element.children {
                newNode.element.addChild(c)
            }
            if let indexInParent = self.indexInParent, isIndented && indexInParent == 0 {
                prevVisible.element.addChild(newNode.element)
            } else {
                guard prevVisible.parent?.insert(node: newNode, after: prevVisible) != nil else { return false }
            }
        }

        root.focussedWidget = newNode
        root.cursorPosition = 0
        root.selected = true
        self.node = newNode
        return true
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
