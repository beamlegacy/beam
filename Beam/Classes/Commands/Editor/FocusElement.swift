//
//  FocusElement.swift
//  Beam
//
//  Created by Sebastien Metrot on 19/03/2021.
//

import Foundation
import BeamCore

class FocusElement: TextEditorCommand {
    static let name: String = "FocusElement"

    var elementId: UUID
    var noteId: UUID
    var cursorPosition: Int
    var oldElementId: UUID?
    var oldNoteId: UUID?
    var oldCursorPosition: Int?

    init(element: UUID, from noteId: UUID, at cursorPosition: Int) {
        self.elementId = element
        self.noteId = noteId
        self.cursorPosition = cursorPosition
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteId, and: elementId),
              let node = context?.nodeFor(elementInstance.element)
              else { return true }

        if let root = node.root {
            let oldFocus = root.focusedWidget as? TextNode
            oldElementId = oldFocus?.elementId
            oldNoteId = oldFocus?.elementNoteId
            oldCursorPosition = root.cursorPosition
        }

        node.focus(position: cursorPosition)
        context?.editor.detectTextFormatterType()

        return true
    }

    override func undo(context: Widget?) -> Bool {
        if let noteId = oldNoteId,
           let elementId = oldElementId,
           let elementInstance = getElement(for: noteId, and: elementId),
           let node = context?.nodeFor(elementInstance.element),
           let cursorPosition = oldCursorPosition {
            node.focus(position: cursorPosition)
            context?.editor.detectTextFormatterType()
        }
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let focusElement = command as? FocusElement,
              elementId == focusElement.elementId,
              noteId == focusElement.noteId
        else { return false }
        cursorPosition = focusElement.cursorPosition
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func focusElement(_ node: ElementNode, cursorPosition: Int) -> Bool {
        guard let noteId = node.displayedElementNoteId else { return false }
        let cmd = FocusElement(element: node.displayedElementId, from: noteId, at: cursorPosition)
        return run(command: cmd, on: node)
    }

    func focus(_ element: BeamElement, in node: ElementNode, leading: Bool = false) {
        if let toFocus = node.nodeFor(element) {
            let textCount = element.kind.isMedia ? 1 : element.text.count
            focusElement(toFocus, cursorPosition: leading ? 0 : textCount)
        }
    }
}
