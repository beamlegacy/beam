//
//  FormatText.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/03/2021.
//

import Foundation
import BeamCore

class FormatText: TextEditorCommand {
    static let name: String = "FormatText"

    var elementId: UUID
    var noteId: UUID
    var oldKind: ElementKind?
    let newKind: ElementKind?
    let newAttribute: BeamText.Attribute?
    let range: Range<Int>?
    var isActive: Bool

    init(in elementId: UUID, of noteId: UUID, for kind: ElementKind?, with attribute: BeamText.Attribute?, for range: Range<Int>?, isActive: Bool) {
        self.elementId = elementId
        self.noteId = noteId
        self.newKind = kind
        self.newAttribute = attribute
        self.range = range
        self.isActive = isActive
        super.init(name: Self.name)
        saveOldKind()
    }

    private func saveOldKind() {
        guard newKind != nil,
              let elementInstance = getElement(for: noteId, and: elementId) else { return }
        self.oldKind = elementInstance.element.kind
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId) else { return false }

        var result = true
        if let newKind = self.newKind {
            elementInstance.element.kind = isActive ? .bullet : newKind
        } else {
            result = runUpdateAttributes(for: elementInstance.element, context: context?.root)
        }
        self.isActive = !isActive

        guard let root = context?.root else { return false }
        root.editor.detectTextFormatterType()
        return result
    }

    private func runUpdateAttributes(for element: BeamElement, context: TextRoot?) -> Bool {
        guard let newAttribute = self.newAttribute else { return false }
        if let range = self.range {
            if isActive {
                element.text.removeAttributes([newAttribute], from: range)
            } else {
                element.text.addAttributes([newAttribute], to: range)
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

    override func undo(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId) else { return false }

        var result: Bool = true
        if let oldKind = self.oldKind, self.newKind != nil {
            elementInstance.element.kind = oldKind
        } else {
            result = runUpdateAttributes(for: elementInstance.element, context: context?.root)
        }
        self.isActive = !isActive

        guard let root = context?.root else { return false }
        root.editor.detectTextFormatterType()
        return result
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func formatText(in node: TextNode, for kind: ElementKind?, with attribute: BeamText.Attribute?, for range: Range<Int>?, isActive: Bool) -> Bool {
        guard let noteId = node.displayedElementNoteId else { return false }
        let cmd = FormatText(in: node.displayedElementId, of: noteId, for: kind, with: attribute, for: range, isActive: isActive)
        return run(command: cmd, on: node)
    }
}
