//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

//TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace all _ with the real test

import Foundation
import BeamCore

extension TextRoot {
    var cmdContext: Widget {
        editor.focusedWidget ?? editor.rootNode
    }

    func increaseNodeIndentation(_ node: TextNode) -> Bool {
        guard let noteTitle = node.elementNoteTitle, !node.readOnly,
              node.parent as? BreadCrumb == nil,
              let newParent = node.previousSibbling() as? TextNode
        else { return false }

        let reparentElement = ReparentElement(for: node.elementId, of: noteTitle, to: newParent.elementId, atIndex: newParent.element.children.count)
        return cmdManager.run(command: reparentElement, on: cmdContext)
    }

    func decreaseNodeIndentation(_ node: TextNode) -> Bool {
        guard let noteTitle = node.elementNoteTitle, !node.readOnly,
              node.parent as? BreadCrumb == nil,
              node.parent?.parent as? BreadCrumb == nil,
              let prevParent = node.unproxyElement.parent,
              let newParent = prevParent.parent,
              let parentIndexInParent = newParent.id == node.elementId ? node.unproxyElement.children.count : prevParent.indexInParent
        else { return false }

        let reparentElement = ReparentElement(for: node.elementId, of: noteTitle, to: newParent.id, atIndex: parentIndexInParent + 1)
        return cmdManager.run(command: reparentElement, on: cmdContext)
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

        cancelNodeSelection()

        root.note?.cmdManager.beginGroup(with: "Delete selected nodes")
        defer { root.note?.cmdManager.endGroup() }

        if let prevWidget = sortedNodes.first?.previousVisibleTextNode() {
            cmdManager.focusElement(prevWidget, position: prevWidget.text.count)
        } else if let nextVisibleNode = sortedNodes.last?.nextVisibleTextNode() {
            cmdManager.focusElement(nextVisibleNode, position: 0)
        }

        for node in sortedNodes.reversed() {
            // Delete Selected Element:
            cmdManager.deleteElement(for: node)
        }

        if createEmptyNodeInPlace || root.element.children.isEmpty {
            guard let noteTitle = root.note?.title else { return }
            let insertEmptyNode = InsertEmptyNode(with: firstParent.element.id, of: noteTitle, at: firstIndexInParent)
            cmdManager.run(command: insertEmptyNode, on: cmdContext)
        }
    }

    func replaceSelection(with str: String) {
        guard let node = focusedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty
        else { return }

        let bText = BeamText(text: str, attributes: root.state.attributes)
        cmdManager.beginGroup(with: "erase selection")
        defer { cmdManager.endGroup() }
        cmdManager.replaceText(in: node, for: selectedTextRange, with: bText)
        cmdManager.cancelSelection(node)
        cmdManager.focusElement(node, position: selectedTextRange.lowerBound + bText.count)
    }

    func deleteForward() {
        guard root.state.nodeSelection == nil else {
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly,
              node.elementNoteTitle != nil else { return }

        if !selectedTextRange.isEmpty {
            cmdManager.deleteText(in: node, for: selectedTextRange)
        } else if cursorPosition != node.text.count {
            cmdManager.deleteText(in: node, for: cursorPosition ..< cursorPosition + 1)
        } else {
            // Delete element forward
            cmdManager.beginGroup(with: "Delete forward")
            defer { cmdManager.endGroup() }
            if let nextVisibleNode = node.nextVisibleTextNode() {
                let pos = cursorPosition
                cmdManager.replaceText(in: node, for: cursorPosition..<cursorPosition, with: nextVisibleNode.text)
                cmdManager.cancelSelection(node)
                cmdManager.focusElement(node, position: pos)
                cmdManager.deleteElement(for: nextVisibleNode)
            }
        }
    }

    func deleteBackward() {
        guard root.state.nodeSelection == nil else {
            editor.cancelPopover()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly else { return }

        if cursorPosition == 0, selectedTextRange.isEmpty {
            if node.element == node.element.note?.children.first {
                return // can't erase the first element of the note
            }
            // Delete element backward

            cmdManager.beginGroup(with: "Delete backward")
            defer { cmdManager.endGroup() }
            if let prevVisibleNode = node.previousVisibleTextNode() {
                let pos = prevVisibleNode.text.count
                cmdManager.replaceText(in: prevVisibleNode, for: pos..<pos, with: node.text)
                cmdManager.focusElement(prevVisibleNode, position: pos)
                cmdManager.deleteElement(for: node)
            }
        } else {
            if selectedTextRange.isEmpty {
                cmdManager.deleteText(in: node, for: cursorPosition - 1 ..< cursorPosition)
            } else {
                cmdManager.deleteText(in: node, for: selectedTextRange)
            }
        }
    }

    func insertNewline() {
        guard root.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        if !node.element.text.isEmpty {
            if !selectedTextRange.isEmpty {
                cmdManager.deleteText(in: node, for: selectedTextRange)
            }

            let bText = BeamText(text: "\n", attributes: [])
            cmdManager.inputText(bText, in: node, at: cursorPosition)
        }
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return markedTextRange != nil
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>?, replacementRange: Range<Int>?) {
        // Logger.shared.logDebug("setMarkedText(string: '\(string)', selectedRange: \(selectedRange), replacementRange: \(replacementRange)")
        guard let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        var range = cursorPosition..<cursorPosition
        if let r = replacementRange {
            range = r
        } else {
            if let markedRange = markedTextRange {
                range = markedRange
            } else {
                range = selectedTextRange
            }
        }

        //Logger.shared.logDebug("   replace sub range \(range) wirth '\(string)'")
        node.text.replaceSubrange(range, with: string)
        cursorPosition = range.upperBound
        markedTextRange = range.lowerBound ..< range.lowerBound + string.count
        cursorPosition = range.lowerBound + string.count
        selectedTextRange = cursorPosition ..< cursorPosition
    }

    public func unmarkText() {
        guard let node = focusedWidget as? TextNode, !node.readOnly else { return }
        markedTextRange = nil
    }

    public func insertText(string: String, replacementRange: Range<Int>?) {
        eraseNodeSelection(createEmptyNodeInPlace: true)
        guard let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        var range = cursorPosition..<cursorPosition
        if let r = replacementRange {
            range = r
        } else {
            if let markedRange = markedTextRange {
                range = markedRange
            } else {
                range = selectedTextRange
            }
        }

        if !range.isEmpty {
            cmdManager.deleteText(in: node, for: range)
        }

        let bText = BeamText(text: string, attributes: root.state.attributes)
        cmdManager.inputText(bText, in: node, at: cursorPosition)

        unmarkText()
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
