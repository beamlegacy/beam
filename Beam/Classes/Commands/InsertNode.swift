//
//  InsertNode.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 23/02/2021.
//

import Foundation

class InsertNode: TextEditorCommand {
    static let name: String = "InsertNode"

    var elementId: UUID
    var noteName: String
    let cursorPosition: Int?
    var newElementId: UUID?
    var text: String?
    var data: Data?

    init(in elementId: UUID, of noteName: String, with cursorPosition: Int?) {
        self.elementId = elementId
        self.noteName = noteName
        self.cursorPosition = cursorPosition
        super.init(name: InsertNode.name)
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }

        let element = decode(data: data) ?? BeamElement()
        if let cursorPosition = self.cursorPosition {
            element.text = node.element.text.extract(range: cursorPosition..<node.element.text.count)
            node.text.removeLast(node.element.text.count - cursorPosition)
        }

        var insertNode: TextNode
        if let linkedRefNode = node as? LinkedReferenceNode {
            guard let newProxyElement = createProxyElement(for: linkedRefNode, and: element) else { return false }
            self.newElementId = newProxyElement.id
            insertNode = node.nodeFor(newProxyElement, withParent: root)
        } else {
            guard let newNode = context?.nodeFor(element, withParent: root) else { return false }
            self.newElementId = element.id
            insertNode = newNode
        }

        guard let result = node.parent?.insert(node: insertNode, after: node) else { return false }
        context?.focus(widget: insertNode)
        return result
    }

    private func createProxyElement(for linkedRefNode: LinkedReferenceNode, and element: BeamElement) -> ProxyElement? {
        guard let proxyElement = linkedRefNode.element as? ProxyElement,
              let actualElement = proxyElement.parent,
              let actualParent = actualElement.parent else { return nil }

        actualParent.addChild(element)
        let elements = actualElement.children
        for c in elements {
            element.addChild(c)
        }
        return ProxyElement(for: element)
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let newElementId = self.newElementId,
              let newElementInstance = getElement(for: noteName, and: newElementId),
              let newNode = context?.nodeFor(newElementInstance.element, withParent: root),
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }

        for c in newNode.element.children {
            node.element.addChild(c)
        }
        if self.cursorPosition != nil {
            let remainingText = newNode.element.text.extract(range: 0..<newNode.text.count)
            node.text.append(remainingText)
        }

        data = encode(element: newElementInstance.element)

        newNode.delete()
        context?.focus(widget: node, cursorPosition: self.cursorPosition)
        return true
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }
}
