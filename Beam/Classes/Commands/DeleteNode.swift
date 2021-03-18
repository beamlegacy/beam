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
    var parentId: UUID?
    var indexInParent: Int?
    var data: Data?
    var oldChildrenData: [Data]?

    init(elementId: UUID, of noteName: String, with deleteNodeMode: DeleteNodeMode) {
        self.elementId = elementId
        self.noteName = noteName
        self.deleteNodeMode = deleteNodeMode
        super.init(name: DeleteNode.name)
    }

    override func run(context: Widget?) -> Bool {
        switch deleteNodeMode {
        case .backward:
            return runBackward(context)
        case .forward:
            return runForward(context)
        case .selected:
            return runDelete(context)
        }
    }

    private func runBackward(_ context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }

        if let previousSibbling = elementInstance.element.previousSibbling() {
            if previousSibbling.children.isEmpty {
                self.previousVisibleElementId = previousSibbling.id
            } else {
                self.previousVisibleElementId = previousSibbling.deepestChildren()?.id
                self.parentId = previousSibbling.id
            }
        } else {
            self.previousVisibleElementId = elementInstance.element.parent?.id
            self.indexInParent = elementInstance.element.indexInParent
        }

        guard let prevVisibleId = self.previousVisibleElementId,
              let prevVisible = getElement(for: noteName, and: prevVisibleId) else { return false }

        for c in elementInstance.element.children {
            prevVisible.element.addChild(c)
        }

        data = encode(element: elementInstance.element)
        prevVisible.element.text.append(elementInstance.element.text)
        elementInstance.element.parent?.removeChild(elementInstance.element)

        // UI Update
        guard let context = context,
              let root = context.root,
              let prevNode = context.nodeFor(prevVisible.element) else { return true }

        root.focus(widget: prevNode, cursorPosition: prevVisible.element.text.count)
        root.cancelSelection()
        return true
    }

    private func runForward(_ context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }

        if elementInstance.element.children.isEmpty {
            if let nextSibbling = elementInstance.element.nextSibbling() {
                self.nextVisibleElementId = nextSibbling.id
            } else {
                self.nextVisibleElementId = elementInstance.element.highestNextSibbling()?.id
                self.previousVisibleElementId = elementInstance.element.highestNextSibbling()?.previousSibbling()?.id
            }
        } else {
            self.nextVisibleElementId = elementInstance.element.children.first?.id
            self.indexInParent = elementInstance.element.children.first?.indexInParent
        }

        guard let nextVisibleId = self.nextVisibleElementId,
              let nextVisible = getElement(for: noteName, and: nextVisibleId) else { return false }

        for c in nextVisible.element.children {
            elementInstance.element.addChild(c)
        }

        elementInstance.element.text.append(nextVisible.element.text)

        data = encode(element: nextVisible.element)
        nextVisible.element.parent?.removeChild(nextVisible.element)

        guard let root = context?.root else { return true }
        root.cancelSelection()
        return true
    }

    private func runDelete(_ context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }

        self.indexInParent = elementInstance.element.indexInParent
        for child in elementInstance.element.children {
            guard let childData = encode(element: child) else { continue }
            oldChildrenData?.append(childData)
        }

        self.previousVisibleElementId = elementInstance.element.parent?.id

        data = encode(element: elementInstance.element)

        // UI Update
        guard let context = context,
              let root = context.root else { return true }
        root.cancelNodeSelection()
        let node = context.nodeFor(elementInstance.element, withParent: context)
        guard let prevVisibleNode = (node.parent ?? context) as? TextNode else { return false }
        if let nextVisibleNode = node.nextVisibleTextNode(), prevVisibleNode === context {
            root.focus(widget: nextVisibleNode, cursorPosition: nextVisibleNode.text.count)
        }
        if let prevWidget = node.previousVisibleTextNode() {
            root.focus(widget: prevWidget, cursorPosition: prevWidget.text.count)
        }
        node.delete()
        return true
    }

    override func undo(context: Widget?) -> Bool {
        switch deleteNodeMode {
        case .backward:
            return undoBackward(context)
        case .forward:
            return undoForward(context)
        case .selected:
            return undoDelete(context)
        }
    }

    private func undoBackward(_ context: Widget?) -> Bool {
        guard let data = self.data,
              let deletedElement = decode(data: data),
              let previousVisibleElementId = self.previousVisibleElementId,
              let previousElementInstance = getElement(for: noteName, and: previousVisibleElementId) else { return false }

        previousElementInstance.element.text.removeLast(deletedElement.text.count)

        for c in previousElementInstance.element.children {
            deletedElement.addChild(c)
        }

        if let indexInParent = self.indexInParent {
            previousElementInstance.element.insert(deletedElement, at: indexInParent)
        } else {
            if let parentId = self.parentId,
               let parentElementInstance = getElement(for: noteName, and: parentId) {
                parentElementInstance.element.parent?.insert(deletedElement, after: parentElementInstance.element)
            } else {
                previousElementInstance.element.parent?.insert(deletedElement, after: previousElementInstance.element)
            }
        }

        // UI Update
        guard let context = context,
              let root = context.root,
              let newLastNode = context.nodeFor(deletedElement) else { return true }
        root.focus(widget: newLastNode)
        return true
    }

    private func undoForward(_ context: Widget?) -> Bool {
        guard let data = self.data,
              let deletedElement = decode(data: data),
              let elementInstance = getElement(for: noteName, and: elementId) else { return false }

        elementInstance.element.text.removeLast(deletedElement.text.count)
        for c in elementInstance.element.children {
            deletedElement.addChild(c)
        }

        if let previousSibblingId = self.previousVisibleElementId,
           let previousSibblingElementInstance = getElement(for: noteName, and: previousSibblingId) {
            previousSibblingElementInstance.element.parent?.insert(deletedElement, after: previousSibblingElementInstance.element)
        } else {
            if let indexInParent = self.indexInParent {
                elementInstance.element.insert(deletedElement, at: indexInParent)
            } else {
                elementInstance.element.parent?.insert(deletedElement, after: elementInstance.element)
            }
        }

        return true
    }

    private func undoDelete(_ context: Widget?) -> Bool {
        guard let deletedElement = decode(data: data),
              let previousVisibleElementId = self.previousVisibleElementId,
              let previousElementInstance = getElement(for: noteName, and: previousVisibleElementId),
              let indexInParent = self.indexInParent else { return false }

        previousElementInstance.element.insert(deletedElement, at: indexInParent)
        if let oldChildrenData = self.oldChildrenData {
            for data in oldChildrenData {
                if let child = decode(data: data) {
                    deletedElement.addChild(child)
                }
            }
        }
        return true
    }
}
