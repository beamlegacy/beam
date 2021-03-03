//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

//TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace all _ with the real test

import Foundation

extension TextRoot {
    func increaseNodeIndentation(_ node: TextNode) -> Bool {
        guard !node.readOnly else { return false }

        let increaseIndentation = IncreaseIndentation(for: node)
        cmdManager.run(command: increaseIndentation)
        return true
    }

    func decreaseNodeIndentation(_ node: TextNode) -> Bool {
        guard !node.readOnly else { return false }

        let decreaseIndentation = DecreaseIndentation(for: node)
        cmdManager.run(command: decreaseIndentation)
        return true
    }

    func increaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }

        cmdManager.beginGroup(with: "IncreaseIndentation")
        for node in selection.sortedRoots {
            let increaseIndentation = IncreaseIndentation(for: node)
            cmdManager.run(command: increaseIndentation)
        }
        cmdManager.endGroup()
    }

    func decreaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }

        cmdManager.beginGroup(with: "DecreaseIndentation")
        for node in selection.sortedRoots.reversed() {

            let decreaseIndentation = DecreaseIndentation(for: node)
            cmdManager.run(command: decreaseIndentation)
        }
        cmdManager.endGroup()
    }

    func increaseIndentation() {
        guard root.state.nodeSelection == nil else {
            increaseNodeSelectionIndentation()
            return
        }
        guard let node = focussedWidget as? TextNode else { return }
        _ = increaseNodeIndentation(node)
    }

    func decreaseIndentation() {
        guard root.state.nodeSelection == nil else {
            decreaseNodeSelectionIndentation()
            return
        }
        guard let node = focussedWidget as? TextNode else { return }
        _ = decreaseNodeIndentation(node)
    }

    func eraseNodeSelection(createEmptyNodeInPlace: Bool) {
        guard let selection = root.state.nodeSelection else { return }
        let sortedNodes = selection.sortedNodes

        // This will be used to create an empty node in place:
        let firstParent = sortedNodes.first?.parent as? TextNode ?? root
        let firstIndexInParent = sortedNodes.first?.indexInParent ?? 0
        var goToPrevious = true
        var nextNode = sortedNodes.first?.previousVisibleTextNode()
        if nextNode == nil {
            nextNode = sortedNodes.last?.nextVisibleTextNode()
            goToPrevious = false
        }

        cmdManager.beginGroup(with: "Delete selected nodes")
        for node in sortedNodes.reversed() {
            guard node as? TextRoot == nil else { continue }
            let deleteNode = DeleteNode(node: node, deleteNodeMode: .selected)
            cmdManager.run(command: deleteNode)
        }

        if createEmptyNodeInPlace {
            let insertEmptyNode = InsertEmptyNode(with: firstParent, at: firstIndexInParent)
            cmdManager.run(command: insertEmptyNode)
        } else if root.element.children.isEmpty {
            // we must create a new first node...
            let insertEmptyNode = InsertEmptyNode(with: root)
            cmdManager.run(command: insertEmptyNode)
        } else {
            assert(nextNode != nil)
            root.focussedWidget = nextNode
            root.cursorPosition = goToPrevious ? nextNode!.text.count : 0
        }
        cmdManager.endGroup()
    }

    func eraseSelection(with str: String = "", and range: Range<Int>? = nil) {
        guard let node = focussedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty else { return }

        let rangeToReplace = range ?? selectedTextRange
        let replaceText = ReplaceText(in: node, for: rangeToReplace, at: cursorPosition, with: str)
        root.cmdManager.run(command: replaceText)
    }

    func deleteForward() {
        guard root.state.nodeSelection == nil else {
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focussedWidget as? TextNode,
              !node.readOnly else { return }

        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition != node.text.count {
            let deleteText = DeleteText(in: node, at: cursorPosition, for: selectedTextRange, backward: false)
            cmdManager.run(command: deleteText)
        } else {
            let deleteNode = DeleteNode(node: node, deleteNodeMode: .forward)
            root.cmdManager.run(command: deleteNode)
        }
    }

    func deleteBackward() {
        guard root.state.nodeSelection == nil else {
            editor.cancelPopover()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focussedWidget as? TextNode,
              !node.readOnly else { return }

        if cursorPosition == 0, selectedTextRange.isEmpty {
            let deleteNode = DeleteNode(node: node, deleteNodeMode: .backward)
            root.cmdManager.run(command: deleteNode)
        } else {
            if selectedTextRange.isEmpty {
                let deleteText = DeleteText(in: node, at: cursorPosition, for: selectedTextRange)
                root.cmdManager.run(command: deleteText)
            } else {
                eraseSelection()
            }
        }
    }

    func insertNewline() {
        guard root.state.nodeSelection == nil,
              let node = focussedWidget as? TextNode,
              !node.readOnly else { return }

        let newLineStr = "\n"
        if !node.element.text.isEmpty {
            if !selectedTextRange.isEmpty {
                eraseSelection(with: newLineStr)
            } else {
                let insertText = InsertText(text: newLineStr, in: node, at: cursorPosition)
                root.cmdManager.run(command: insertText)
            }
        }
    }
    
    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return !markedTextRange.isEmpty
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>, replacementRange: Range<Int>) {
        guard let node = focussedWidget as? TextNode,
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
        guard let node = focussedWidget as? TextNode, !node.readOnly else { return }
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        eraseNodeSelection(createEmptyNodeInPlace: true)
        guard let node = focussedWidget as? TextNode, !node.readOnly else { return }

        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }
        if range.isEmpty {
            let insertText = InsertText(text: string, in: node, at: cursorPosition)
            root.cmdManager.run(command: insertText)
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
        guard let node = focussedWidget as? TextNode else { return }
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
