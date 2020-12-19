//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation

extension TextRoot {
    func eraseSelection() {
        guard !selectedTextRange.isEmpty else { return }

        node.text.removeSubrange(selectedTextRange)
        cursorPosition = selectedTextRange.lowerBound
        if cursorPosition == NSNotFound {
            cursorPosition = node.text.count
        }
        cancelSelection()
    }

    func increaseIndentation() {
        guard let newParent = node.previousSibblingNode() else { return }
        newParent.addChild(node)
    }

    func decreaseIndentation() {
        guard let parent = node.parent else { return }
        guard let newParent = parent.parent else { return }

        _ = newParent.insert(node: node, after: parent)
    }

    func deleteForward() {
        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition != node.text.count {
            node.text.remove(count: 1, at: cursorPosition)
            cancelSelection()
        } else {
            if let nextNode = node.nextVisible() {
                let remainingText = nextNode.text
                // Reparent existing children to the node we're merging in
                for c in nextNode.children {
                    node.addChild(c)
                }

                nextNode.delete()
                node.text.append(remainingText)
            }
            cancelSelection()
        }
    }

    func deleteBackward() {
        if !selectedTextRange.isEmpty {
            eraseSelection()
        } else if cursorPosition == 0 {
            if let nextNode = node.previousVisible() {
                let remainingText = node.text

                // Reparent existing children to the node we're merging in
                for c in node.element.children {
                    nextNode.element.addChild(c)
                }

                node.delete()
                node = nextNode

                cursorPosition = node.text.count
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
        defer {
            if !undoManager.isRedoing {
                lastCommand = command
            }
        }

        guard let commandDef = commands[command] else { return }
        guard commandDef.undo else { return }
        guard !(commandDef.coalesce && lastCommand == command) else { return }

        let state = TextState(text: self.node.text, selectedTextRange: selectedTextRange, markedTextRange: markedTextRange, cursorPosition: cursorPosition)
        undoManager.registerUndo(withTarget: self, handler: { (selfTarget) in
            if commandDef.redo {
                selfTarget.lastCommand = .none
                selfTarget.pushUndoState(command) // push the redo!
            }

            selfTarget.node.text = state.text
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
        markedTextRange = 0..<0
    }

    public func insertText(string: String, replacementRange: Range<Int>) {
        pushUndoState(.insertText)

        let c = string.count
        var range = cursorPosition..<cursorPosition
        if !replacementRange.isEmpty {
            range = replacementRange
        }
        if !selectedTextRange.isEmpty {
            range = selectedTextRange
        }

        node.text.replaceSubrange(range, with: string)
        cursorPosition = range.lowerBound + c
        cancelSelection()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        let r1 = rectAt(range.lowerBound)
        let r2 = rectAt(range.upperBound)
        return (r1.union(r2), range)
    }
}
