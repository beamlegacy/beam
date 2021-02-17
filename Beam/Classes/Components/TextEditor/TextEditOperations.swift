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
        guard !node.readOnly,
        let newParent = node.previousSibbling() as? TextNode else { return false }
        // Prepare Undo:
        guard let currentParent = node.parent as? TextNode,
              let indexInParent = node.indexInParent else { return false }
        undoManager.registerUndo(withTarget: self) { selfTarget in
            selfTarget.undoManager.registerUndo(withTarget: selfTarget) { selfTarget in
                _ = selfTarget.increaseNodeIndentation(node)
            }
            currentParent.element.insert(node.element, at: indexInParent)
        }
        undoManager.setActionName("Increase indentation")

        newParent.element.addChild(node.element)
        return true
    }

    func decreaseNodeIndentation(_ node: TextNode) -> Bool {
        guard !node.readOnly, let parent = node.parent as? TextNode, let newParent = parent.parent as? TextNode else { return false }

        // Prepare Undo:
        guard let indexInParent = node.indexInParent else { return false }

        undoManager.registerUndo(withTarget: self) { selfTarget in
            selfTarget.undoManager.registerUndo(withTarget: selfTarget) { selfTarget in
                _ = selfTarget.decreaseNodeIndentation(node)
            }
            parent.element.insert(node.element, at: indexInParent)
        }
        undoManager.setActionName("Decrease indentation")

        newParent.element.insert(node.element, after: parent.element)

        return true
    }

    func increaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }

        undoManager.beginUndoGrouping()
        for node in selection.sortedRoots {
            //TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace _ with the real test
            _ = increaseNodeIndentation(node)
        }
        undoManager.endUndoGrouping()
        undoManager.setActionName("Increase indentation")
    }

    func decreaseNodeSelectionIndentation() {
        guard let selection = root.state.nodeSelection else { return }
        undoManager.beginUndoGrouping()
        for node in selection.sortedRoots.reversed() {
            //TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace _ with the real test
            _ = decreaseNodeIndentation(node)
        }
        undoManager.endUndoGrouping()
        undoManager.setActionName("Decrease indentation")
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

    func erase(node: TextNode, enableRedo: Bool = true) -> Bool {
        guard let oldParent = node.parent as? TextNode,
              let oldIndexInParent = node.indexInParent else { return false }
        let oldChildren = node.children
        undoManager.registerUndo(withTarget: self) { selfTarget in
            if enableRedo {
                selfTarget.undoManager.registerUndo(withTarget: selfTarget) { selfTarget in
                    _ = selfTarget.erase(node: node)
                }
            }
            oldParent.element.insert(node.element, at: oldIndexInParent)
            for oldChild in oldChildren {
                guard let oldChild = oldChild as? TextNode else { return }
                node.element.addChild(oldChild.element)
            }
        }

        // reparent all children to previous sibbling or parent:
        if let previous = node.previousSibbling() as? TextNode {
            for child in node.children {
                guard let child = child as? TextNode else { return false }
                previous.element.addChild(child.element)
            }
        } else {
            for (i, child) in node.children.enumerated() {
                guard let child = child as? TextNode else { return false }
                oldParent.element.insert(child.element, at: oldIndexInParent + i)
            }
        }
        oldParent.element.removeChild(node.element)
        undoManager.setActionName("Erase node")

        return true
    }

    func createEmptyNode(withParent parent: TextNode, atIndex index: Int = 0) {
        let element = BeamElement()

        parent.element.insert(element, at: index)
        root.cursorPosition = 0

        let newNode = nodeFor(element)
        focussedWidget = newNode

        undoManager.registerUndo(withTarget: self) { selfTarget in
            _ = selfTarget.erase(node: newNode, enableRedo: false)
        }
    }

    func eraseNodeSelection(createEmptyNodeInPlace: Bool) {
        guard let selection = root.state.nodeSelection else { return }
        let sortedNodes = selection.sortedNodes

        // This will be used to create an empty node in place:
        let firstParent = sortedNodes.first?.parent as? TextNode ?? root
        let firstIndexInParent = sortedNodes.first?.indexInParent ?? 0
        var goToPrevious = true
        var nextNode = sortedNodes.last?.previousVisibleTextNode()
        if nextNode == nil {
            nextNode = sortedNodes.last?.nextVisibleTextNode()
            goToPrevious = false
        }

        let nodes = sortedNodes.reversed()
        let multiple = nodes.isEmpty
        undoManager.beginUndoGrouping()
        for node in nodes {
            _ = erase(node: node)
        }

        cancelNodeSelection()

        if createEmptyNodeInPlace {
            createEmptyNode(withParent: firstParent, atIndex: firstIndexInParent)
        } else if root.element.children.isEmpty {
            // we must create a new first node...
            createEmptyNode(withParent: root, atIndex: 0)
        } else {
            assert(nextNode != nil)
            root.focussedWidget = nextNode
            root.cursorPosition = goToPrevious ? nextNode!.text.count : 0
        }

        undoManager.endUndoGrouping()
        undoManager.setActionName(multiple ? "Erase selected nodes" : "Erase selected node")
    }

    func eraseSelection() {
        guard let node = focussedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty else { return }

        node.text.removeSubrange(selectedTextRange)
        cursorPosition = selectedTextRange.lowerBound
        if cursorPosition == NSNotFound {
            cursorPosition = node.text.count
        }
        cancelSelection()
    }

    func deleteForward() {
        guard root.state.nodeSelection == nil else {
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focussedWidget as? TextNode else { return }
        guard !node.readOnly else { return }
        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition != node.text.count {
            node.text.remove(count: 1, at: cursorPosition)
            cancelSelection()
        } else {
            if let nextNode = node.nextVisible() as? TextNode {
                let remainingText = nextNode.text
                // Reparent existing children to the node we're merging in
                for c in nextNode.children {
                    guard let c = c as? TextNode else { return }
                    node.element.addChild(c.element)
                }

                nextNode.delete()
                node.text.append(remainingText)
            }
            cancelSelection()
        }
    }

    func deleteBackward() {
        guard root.state.nodeSelection == nil else {
            editor.cancelPopover()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focussedWidget as? TextNode else { return }
        guard !node.readOnly else { return }
        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition == 0 {
            if let nextNode = node.previousVisible() as? TextNode {
                let remainingText = node.text

                // Reparent existing children to the node we're merging in
                for c in node.element.children {
                    nextNode.element.addChild(c)
                }

                node.delete()
                self.focussedWidget = nextNode

                cursorPosition = nextNode.text.count
                nextNode.text.append(remainingText)
            }
            cancelSelection()
        } else {
            cursorPosition = node.position(before: cursorPosition)
            node.text.remove(count: 1, at: cursorPosition)
            cancelSelection()
        }
    }

    func insertNewline() {
        guard root.state.nodeSelection == nil else { return }
        guard let node = focussedWidget as? TextNode else { return }
        guard !node.readOnly else { return }
        if !selectedTextRange.isEmpty {
            node.text.removeSubrange(selectedTextRange)
            node.text.insert("\n", at: selectedTextRange.startIndex)
            cursorPosition = node.position(after: selectedTextRange.startIndex)
            if cursorPosition == NSNotFound {
                cursorPosition = node.text.count
            }
        } else if cursorPosition != 0 && node.text.count != 0 {
            node.text.insert("\n", at: cursorPosition)
            cursorPosition = node.position(after: cursorPosition)
        }
        cancelSelection()
    }

    func pushUndoState(_ command: Command) {
        guard let node = focussedWidget as? TextNode else { return }
        guard !node.readOnly else { return }
        defer {
            if !undoManager.isRedoing {
                lastCommand = command
            }
        }

        guard let commandDef = commands[command], commandDef.undo, !(commandDef.coalesce && lastCommand == command) else { return }

        let state = TextState(text: node.text, selectedTextRange: selectedTextRange, markedTextRange: markedTextRange, cursorPosition: cursorPosition)
        undoManager.registerUndo(withTarget: self, handler: { (selfTarget) in
            if commandDef.redo {
                selfTarget.lastCommand = .none
                selfTarget.pushUndoState(command) // push the redo!
            }

            guard let selfNode = selfTarget.focussedWidget as? TextNode else { return }
            selfNode.text = state.text
            selfTarget.selectedTextRange = state.selectedTextRange
            selfTarget.markedTextRange = state.markedTextRange
            selfTarget.cursorPosition = state.cursorPosition
        })
        undoManager.setActionName(commandDef.name)
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return !markedTextRange.isEmpty
    }

    public func setMarkedText(string: String, selectedRange: Range<Int>, replacementRange: Range<Int>) {
        guard let node = focussedWidget as? TextNode else { return }
        guard !node.readOnly else { return }
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
        pushUndoState(.insertText)

        let c = string.count
        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }

        let bString = BeamText(text: string, attributes: state.attributes)
        node.text.replaceSubrange(range, with: bString)
        cursorPosition = range.lowerBound + c
        cancelSelection()
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
