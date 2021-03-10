//
//  FormattingText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/03/2021.
//

import Foundation

class FormattingText: TextEditorCommand {
    static let name: String = "FormattingText"

    var elementId: UUID
    var noteName: String
    var oldKind: ElementKind?
    let newKind: ElementKind?
    let newAttribute: BeamText.Attribute?
    let range: Range<Int>?
    var isActive: Bool

    init(in elementId: UUID, of noteName: String, for kind: ElementKind?, with attribute: BeamText.Attribute?, for range: Range<Int>?, isActive: Bool) {
        self.elementId = elementId
        self.noteName = noteName
        self.newKind = kind
        self.newAttribute = attribute
        self.range = range
        self.isActive = isActive
        super.init(name: FormattingText.name)
        saveOldKind()
    }

    private func saveOldKind() {
        guard newKind != nil,
              let elementInstance = getElement(for: noteName, and: elementId) else { return }
        self.oldKind = elementInstance.element.kind
    }

    override func run(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }

        var result = true
        if let newKind = self.newKind {
            node.element.kind = isActive ? .bullet : newKind
        } else {
            result = runUpdateAttributes(for: node, context: context)
        }
        self.isActive = !isActive
        context?.editor.detectFormatterType()
        return result
    }

    private func runUpdateAttributes(for node: TextNode, context: TextRoot?) -> Bool {
        guard let newAttribute = self.newAttribute else { return false }
        if let range = self.range {
            if isActive {
                node.text.removeAttributes([newAttribute], from: range)
            } else {
                node.text.addAttributes([newAttribute], to: range)
            }
        }

        if let index = context?.state.attributes.firstIndex(of: newAttribute),
           ((context?.state.attributes.contains(newAttribute)) != nil), isActive {
            context?.state.attributes.remove(at: index)
        } else {
            context?.state.attributes.append(newAttribute)
        }
        return true
    }

    override func undo(context: TextRoot?) -> Bool {
        guard let root = context,
              let elementInstance = getElement(for: noteName, and: elementId),
              let node = context?.nodeFor(elementInstance.element, withParent: root) else { return false }

        var result: Bool = true
        if let oldKind = self.oldKind, self.newKind != nil {
            node.element.kind = oldKind
        } else {
            result = runUpdateAttributes(for: node, context: context)
        }
        self.isActive = !isActive
        context?.editor.detectFormatterType()
        return result
    }

    override func coalesce(command: Command<TextRoot>) -> Bool {
        return false
    }
}
