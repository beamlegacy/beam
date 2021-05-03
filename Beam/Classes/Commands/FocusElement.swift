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
    var noteTitle: String
    var cursorPosition: Int
    var oldElementId: UUID?
    var oldNoteTitle: String?
    var oldCursorPosition: Int?

    init(element: UUID, from noteTitle: String, at cursorPosition: Int) {
        self.elementId = element
        self.noteTitle = noteTitle
        self.cursorPosition = cursorPosition
        super.init(name: Self.name)
    }

    override func run(context: Widget?) -> Bool {
        guard let elementInstance = getElement(for: noteTitle, and: elementId),
              let node = context?.nodeFor(elementInstance.element)
              else { return true }

        if let root = node.root {
            let oldFocus = root.focusedWidget as? TextNode
            oldElementId = oldFocus?.elementId
            oldNoteTitle = oldFocus?.elementNoteTitle
            oldCursorPosition = root.cursorPosition
        }

        node.focus(position: cursorPosition)
        context?.editor.detectFormatterType()

        return true
    }

    override func undo(context: Widget?) -> Bool {
        if let noteTitle = oldNoteTitle,
           let elementId = oldElementId,
           let elementInstance = getElement(for: noteTitle, and: elementId),
           let node = context?.nodeFor(elementInstance.element),
           let cursorPosition = oldCursorPosition {
            node.focus(position: cursorPosition)
            context?.editor.detectFormatterType()
        }
        return true
    }

    override func coalesce(command: Command<Widget>) -> Bool {
        guard let focusElement = command as? FocusElement,
              elementId == focusElement.elementId,
              noteTitle == focusElement.noteTitle
        else { return false }
        cursorPosition = focusElement.cursorPosition
        return true
    }
}

extension CommandManager where Context == Widget {
    @discardableResult
    func focusElement(_ node: TextNode, cursorPosition: Int) -> Bool {
        guard let title = node.elementNoteTitle else { return false }
        let cmd = FocusElement(element: node.elementId, from: title, at: cursorPosition)
        return run(command: cmd, on: node)
    }

    func focus(_ element: BeamElement, in node: TextNode) {
        if let toFocus = node.nodeFor(element) {
            focusElement(toFocus, cursorPosition: element.text.count)
        }
    }
}
