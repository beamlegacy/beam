//
//  FormattingText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/03/2021.
//

import Foundation

class FormattingText: Command {
    var name: String = "FormattingText"

    var node: TextNode
    var element: BeamElement
    var oldKind: ElementKind?
    let newKind: ElementKind?
    let newAttribute: BeamText.Attribute?
    let range: Range<Int>?
    var isActive: Bool

    init(of node: TextNode, of kind: ElementKind?, with attribute: BeamText.Attribute?, for range: Range<Int>?, isActive: Bool) {
        self.node = node
        self.element = node.element
        self.newKind = kind
        if newKind != nil {
            self.oldKind = node.elementKind
        }
        self.newAttribute = attribute
        self.range = range
        self.isActive = isActive
    }

    func run() -> Bool {
        var result: Bool = true
        let newNode = node.nodeFor(self.element)

        if let newKind = self.newKind {
            newNode.element.kind = isActive ? .bullet : newKind
        } else {
            result = runUpdateAttributes(for: newNode)
        }
        self.isActive = !isActive
        self.node = newNode
        self.element = newNode.element
        newNode.root?.editor.detectFormatterType()
        return result
    }

    private func runUpdateAttributes(for newNode: TextNode) -> Bool {
        guard let newAttribute = self.newAttribute else { return false }
        if let range = self.range {
            if isActive {
                newNode.text.removeAttributes([newAttribute], from: range)
            } else {
                newNode.text.addAttributes([newAttribute], to: range)
            }
        }

        if let index = newNode.root?.state.attributes.firstIndex(of: newAttribute),
           ((newNode.root?.state.attributes.contains(newAttribute)) != nil), isActive {
            newNode.root?.state.attributes.remove(at: index)
        } else {
            newNode.root?.state.attributes.append(newAttribute)
        }
        return true
    }

    func undo() -> Bool {
        var result: Bool = true
        let newNode = node.nodeFor(self.element)

        if let oldKind = self.oldKind, self.newKind != nil {
            newNode.element.kind = oldKind
        } else {
            result = runUpdateAttributes(for: newNode)
        }
        self.isActive = !isActive
        newNode.root?.editor.detectFormatterType()
        return result
    }

    func coalesce(command: Command) -> Bool {
        return false
    }
}
