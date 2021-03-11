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

class DeleteNode: TextEditorCommand {
    static let name: String = "DeleteNode"

    var elementId: UUID
    var noteName: String
    let deleteNodeMode: DeleteNodeMode
    var previousVisibleElementId: UUID?
    var nextVisibleElementId: UUID?
    var isIndented: Bool = false
    var indexInParent: Int?
    var data: Data?
    var oldChildrenData: [Data]?

    init(elementId: UUID, of noteName: String, with deleteNodeMode: DeleteNodeMode) {
        self.elementId = elementId
        self.noteName = noteName
        self.deleteNodeMode = deleteNodeMode
        super.init(name: DeleteNode.name)
    }

    override func run(context: TextRoot?) -> Bool {
        switch deleteNodeMode {
        case .backward:
            return runBackward(context)
        case .forward:
            return runForward(context)
        case .selected:
            return runDelete(context)
        }
    }

    private func isIntended(node: TextNode) {
        guard let parent = node.parent as? TextNode,
              parent.parent as? TextNode != nil else { return }
        self.isIndented = true
        self.indexInParent = node.indexInParent
    }

    private func runBackward(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root),
              let prevVisible = node.previousVisible() as? TextNode else { return false }

        isIntended(node: node)
        self.previousVisibleElementId = prevVisible.element.id

        for c in node.element.children {
            prevVisible.element.addChild(c)
        }

        data = encode(element: elementInstance.element)
        node.delete()

        context?.focus(widget: prevVisible, cursorPosition: prevVisible.element.text.count)
        prevVisible.element.text.append(elementInstance.element.text)
        context?.cancelSelection()
        return true
    }

    private func runForward(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root),
              let nextVisible = node.nextVisible() as? TextNode else { return false }

        isIntended(node: nextVisible)

        for c in nextVisible.element.children {
            node.element.addChild(c)
        }
        self.nextVisibleElementId = nextVisible.element.id
        node.element.text.append(nextVisible.element.text)

        data = encode(element: nextVisible.element)
        nextVisible.delete()

        context?.cancelSelection()
        return true
    }

    private func runDelete(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else {
            return false
        }

        var prevVisibleNode: TextNode
        if let prevVisible = node.parent as? TextNode {
            prevVisibleNode = prevVisible
        } else if let prevVisible = context {
            prevVisibleNode = prevVisible
        } else {
            return false
        }

        self.indexInParent = node.indexInParent
        for child in node.children {
            guard let child = child as? TextNode,
                  let childData = encode(element: child.element) else { continue }
            oldChildrenData?.append(childData)
        }

        self.previousVisibleElementId = prevVisibleNode.element.id

        data = encode(element: elementInstance.element)
        context?.cancelNodeSelection()
        if let nextVisibleNode = node.nextVisibleTextNode(), prevVisibleNode === context {
            context?.focus(widget: nextVisibleNode)
        }
        if let prevWidget = node.previousVisibleTextNode() {
            context?.focus(widget: prevWidget)
        }
        node.delete()
        return true
    }

    override func undo(context: TextRoot?) -> Bool {
        switch deleteNodeMode {
        case .backward:
            return undoBackward(context)
        case .forward:
            return undoForward(context)
        case .selected:
            return undoDelete(context)
        }
    }

    private func undoBackward(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let data = self.data,
              let deletedElement = decode(data: data),
              let previousVisibleElementId = self.previousVisibleElementId,
              let previousElementInstance = getElement(for: noteName, and: previousVisibleElementId),
              let previousNode = context?.nodeFor(previousElementInstance.element, withParent: root),
              let newLastNode = context?.nodeFor(deletedElement, withParent: root) else { return false }

        previousNode.element.text.removeLast(deletedElement.text.count)

        for c in previousNode.element.children {
            newLastNode.element.addChild(c)
        }
        var result = true
        if let indexInParent = self.indexInParent, isIndented {
            previousNode.element.insert(newLastNode.element, at: indexInParent)
        } else {
            guard let res = newLastNode.parent?.insert(node: newLastNode, after: previousNode) else { return false }
            result = res
        }
        context?.focus(widget: newLastNode)
        return result
    }

    private func undoForward(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let data = self.data,
              let deletedElement = decode(data: data),
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root),
              let deletedNode = context?.nodeFor(deletedElement, withParent: root) else { return false }

        node.text.removeLast(deletedElement.text.count)
        for c in node.element.children {
            deletedNode.element.addChild(c)
        }

        var result = true
        if let indexInParent = self.indexInParent, isIndented {
            node.element.insert(deletedNode.element, at: indexInParent)
        } else {
            guard let res = node.parent?.insert(node: deletedNode, after: node) else { return false }
            result = res
        }
        return result
    }

    private func undoDelete(_ context: TextRoot?) -> Bool {
        guard let root = context,
              let data = self.data,
              let deletedElement = decode(data: data),
              let previousVisibleElementId = self.previousVisibleElementId,
              let previousElementInstance = getElement(for: noteName, and: previousVisibleElementId),
              let previousNode = context?.nodeFor(previousElementInstance.element, withParent: root),
              let node = context?.nodeFor(deletedElement, withParent: root),
              let indexInParent = self.indexInParent else { return false }

        previousNode.element.insert(node.element, at: indexInParent)
        if let oldChildrenData = self.oldChildrenData {
            for data in oldChildrenData {
                if let child = decode(data: data) {
                    node.element.addChild(child)
                }
            }
        }
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }
}
