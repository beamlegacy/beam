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

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteName, and: elementId) else { return false }

        let element = decode(data: data) ?? BeamElement()
        if let cursorPosition = self.cursorPosition {
            element.text = elementInstance.element.text.extract(range: cursorPosition..<elementInstance.element.text.count)
            elementInstance.element.text.removeLast(elementInstance.element.text.count - cursorPosition)
        }

        if let proxyElement = elementInstance.element as? ProxyElement {
        }
        self.newElementId = element.id

        elementInstance.element.parent?.insert(element, after: elementInstance.element)

        // UI Update
        guard let context = context,
              let root = context.root,
              let insertedNode = context.nodeFor(element) else { return true }
        root.focus(widget: insertedNode)
        return true
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

    override func undo(context: Widget?) -> Bool {
        guard let newElementId = self.newElementId,
              let newElementInstance = getElement(for: noteName, and: newElementId),
              let elementInstance = getElement(for: noteName, and: elementId)
        else { return false }

        for c in newElementInstance.element.children {
            elementInstance.element.addChild(c)
        }
        if self.cursorPosition != nil {
            let remainingText = newElementInstance.element.text.extract(range: 0..<newElementInstance.element.text.count)
            elementInstance.element.text.append(remainingText)
        }

        data = encode(element: newElementInstance.element)

        newElementInstance.element.parent?.removeChild(newElementInstance.element)

        // UI Update
        guard  let context = context,
               let root = context.root,
               let node = context.nodeFor(elementInstance.element) else { return true }

        root.focus(widget: node, cursorPosition: self.cursorPosition)
        return true
    }
}
