//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

//TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace all _ with the real test

import Foundation

extension TextRoot {
    var cmdContext: Widget {
        editor.focusedWidget ?? editor.rootNode
    }

    func increaseNodeIndentation(_ node: TextNode) -> Bool {
        guard let noteTitle = node.elementNoteTitle, !node.readOnly,
              let newParent = node.previousSibbling() as? TextNode
        else { return false }

        let reparentElement = ReparentElement(for: node.elementId, of: noteTitle, to: newParent.elementId, atIndex: newParent.element.children.count)
        return root.note?.cmdManager.run(command: reparentElement, on: cmdContext) ?? false
    }

    func decreaseNodeIndentation(_ node: TextNode) -> Bool {
        guard let noteTitle = node.elementNoteTitle, !node.readOnly,
              let prevParent = node.parent as? TextNode,
              let newParent = prevParent.parent as? TextNode,
              let parentIndexInParent = prevParent.element.indexInParent
        else { return false }

        let reparentElement = ReparentElement(for: node.elementId, of: noteTitle, to: newParent.elementId, atIndex: parentIndexInParent + 1)
        return root.note?.cmdManager.run(command: reparentElement, on: cmdContext) ?? false
    }

    func increaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }

        root.note?.cmdManager.beginGroup(with: "IncreaseIndentationGroup")
        for node in selection.sortedRoots {
            _ = increaseNodeIndentation(node)
        }
        root.note?.cmdManager.endGroup()
    }

    func decreaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }

        root.note?.cmdManager.beginGroup(with: "DecreaseIndentationGroup")
        for node in selection.sortedRoots.reversed() {
            _ = decreaseNodeIndentation(node)
        }
        root.note?.cmdManager.endGroup()
    }

    func increaseIndentation() {
        guard root.state.nodeSelection == nil else {
            increaseNodeSelectionIndentation()
            return
        }
        guard let node = focusedWidget as? TextNode else { return }
        _ = increaseNodeIndentation(node)
    }

    func decreaseIndentation() {
        guard root.state.nodeSelection == nil else {
            decreaseNodeSelectionIndentation()
            return
        }
        guard let node = focusedWidget as? TextNode else { return }
        _ = decreaseNodeIndentation(node)
    }

    func eraseNodeSelection(createEmptyNodeInPlace: Bool) {
        guard let selection = root.state.nodeSelection else { return }
        let sortedNodes = selection.sortedNodes

        // This will be used to create an empty node in place:
        let firstParent = sortedNodes.first?.parent as? TextNode ?? root
        let firstIndexInParent = sortedNodes.first?.indexInParent ?? 0

        root.note?.cmdManager.beginGroup(with: "Delete selected nodes")
        for node in sortedNodes.reversed() {
            guard let noteTitle = node.elementNoteTitle else { continue }
            let deleteNode = DeleteNode(elementId: node.elementId, of: noteTitle, with: .selected)
            root.note?.cmdManager.run(command: deleteNode, on: cmdContext)
        }

        if createEmptyNodeInPlace || root.element.children.isEmpty {
            guard let noteTitle = root.note?.title else { return }
            let insertEmptyNode = InsertEmptyNode(with: firstParent.element.id, of: noteTitle, at: firstIndexInParent)
            root.note?.cmdManager.run(command: insertEmptyNode, on: cmdContext)
        }
        root.note?.cmdManager.endGroup()
    }

    func eraseSelection(with str: String = "", and range: Range<Int>? = nil) {
        guard let node = focusedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty,
              let noteTitle = node.elementNoteTitle else { return }

        let rangeToReplace = range ?? selectedTextRange
        let bText = BeamText(text: str, attributes: root.state.attributes)
        let replaceText = ReplaceText(in: node.elementId, of: noteTitle, for: rangeToReplace, at: cursorPosition, with: bText)
        root.note?.cmdManager.run(command: replaceText, on: cmdContext)
    }

    func deleteForward() {
        guard root.state.nodeSelection == nil else {
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly,
              let noteTitle = node.elementNoteTitle else { return }

        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition != node.text.count {
            let deleteText = DeleteText(in: node.elementId, of: noteTitle, at: cursorPosition, for: selectedTextRange, backward: false)
            root.note?.cmdManager.run(command: deleteText, on: cmdContext)
        } else {
            let deleteNode = DeleteNode(elementId: node.elementId, of: noteTitle, with: .forward)
            root.note?.cmdManager.run(command: deleteNode, on: cmdContext)
        }
    }

    func deleteBackward() {
        guard root.state.nodeSelection == nil else {
            editor.cancelPopover()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly,
              let noteTitle = node.elementNoteTitle else { return }

        if cursorPosition == 0, selectedTextRange.isEmpty {
            if node.element == node.element.note?.children.first {
                return // can't erase the first element of the note
            }
            let deleteNode = DeleteNode(elementId: node.elementId, of: noteTitle, with: .backward)
            root.note?.cmdManager.run(command: deleteNode, on: cmdContext)
        } else {
            if selectedTextRange.isEmpty {
                let deleteText = DeleteText(in: node.elementId, of: noteTitle, at: cursorPosition, for: selectedTextRange)
                root.note?.cmdManager.run(command: deleteText, on: cmdContext)
            } else {
                eraseSelection()
            }
        }
    }

    func insertNewline() {
        guard root.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              let noteTitle = node.elementNoteTitle, !node.readOnly else { return }

        let newLineStr = "\n"
        if !node.element.text.isEmpty {
            if !selectedTextRange.isEmpty {
                eraseSelection(with: newLineStr)
            } else {
                let bText = BeamText(text: "\n", attributes: [])
                let insertText = InsertText(text: bText, in: node.elementId, of: noteTitle, at: cursorPosition)
                root.note?.cmdManager.run(command: insertText, on: cmdContext)
            }
        }
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return !markedTextRange.isEmpty
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>, replacementRange: Range<Int>) {
        guard let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !markedTextRange.isEmpty {
            range = markedTextRange
        }

        if !self.selectedTextRange.isEmpty {
            range = self.selectedTextRange
        }

        node.text.replaceSubrange(range, with: string)
        cursorPosition = range.upperBound
        cancelSelection()
        markedTextRange = range
        if markedTextRange.isEmpty {
            markedTextRange = node.text.clamp(markedTextRange.lowerBound ..< (markedTextRange.upperBound + string.count))
        }
        self.selectedTextRange = markedTextRange
        cursorPosition = self.selectedTextRange.upperBound
    }

    public func unmarkText() {
        guard let node = focusedWidget as? TextNode, !node.readOnly else { return }
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        eraseNodeSelection(createEmptyNodeInPlace: true)
        guard let node = focusedWidget as? TextNode,
              let noteTitle = node.elementNoteTitle, !node.readOnly else { return }

        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }
        if range.isEmpty {
            let bText = BeamText(text: string, attributes: root.state.attributes)
            let insertText = InsertText(text: bText, in: node.elementId, of: noteTitle, at: cursorPosition)
            root.note?.cmdManager.run(command: insertText, on: cmdContext)
        } else {
            eraseSelection(with: string, and: range)
        }

    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        let r1 = rectAt(range.lowerBound)
        let r2 = rectAt(range.upperBound)
        return (r1.union(r2), range)
    }

    public func updateTextAttributesAtCursorPosition() {
        guard let node = focusedWidget as? TextNode else { return }
        let ranges = node.text.rangesAt(position: cursorPosition)
        switch ranges.count {
        case 0:
            state.attributes = []
        case 1:
            guard let range = ranges.first else { return }
            state.attributes = BeamText.removeLinks(from: range.attributes)
        case 2:
            guard let range1 = ranges.first, let range2 = ranges.last else { return }
            if !range1.attributes.contains(where: { $0.isLink }) {
                state.attributes = range1.attributes
            } else if !range2.attributes.contains(where: { $0.isLink }) {
                state.attributes = range2.attributes
            } else {
                // They both contain links, let's take the attributes from the left one and remove the link attribute
                state.attributes = BeamText.removeLinks(from: range1.attributes)
            }
        default:
            fatalError() // NOPE!
        }
    }

}
