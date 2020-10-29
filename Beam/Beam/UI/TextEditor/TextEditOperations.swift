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

        node.text.removeSubrange(node.text.range(from: selectedTextRange))
        cursorPosition = selectedTextRange.lowerBound
        if cursorPosition == NSNotFound {
            cursorPosition = node.text.count
        }
        cancelSelection()
    }

    func increaseIndentation() {
        guard let p = node.parent,
              let replacementPos = node.indexInParent
        else { return }
        let newParent = TextNode(bullet: node.bullet?.note?.createBullet(CoreDataManager.shared.mainContext, content: "", afterBullet: node.bullet), recurse: false)
        p.setChild(newParent, at: replacementPos)
        newParent.addChild(node)
    }

    func decreaseIndentation() {
        guard let p = node.parent,
              p.parent != nil,
              p.children.count == 1,
              p.text.isEmpty,
              let replacementPos = p.indexInParent
        else { return }

        p.parent?.setChild(node, at: replacementPos)
        if p.children.isEmpty {
            p.bullet?.delete(coreDataManager.mainContext)
        }
    }

    func deleteForward() {
        if !selectedTextRange.isEmpty {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            cursorPosition = selectedTextRange.lowerBound
            if cursorPosition == NSNotFound {
                cursorPosition = node.text.count
            }
        } else if cursorPosition != node.text.count {
            node.text.remove(at: node.text.index(at: cursorPosition))
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

        }
        cancelSelection()
    }

    func deleteBackward() {
        if !selectedTextRange.isEmpty {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            cursorPosition = selectedTextRange.lowerBound
            if cursorPosition == NSNotFound {
                cursorPosition = node.text.count
            }
            cancelSelection()
        } else {
            if cursorPosition == 0 {
                if let nextNode = node.previousVisible() {
                    let remainingText = node.text
                    if let bullet = node.bullet {
                        node.parent?.bullet?.removeFromChildren(bullet)
                    }

                    // Reparent existing children to the node we're merging in
                    for c in node.children {
                        nextNode.addChild(c)
                        if let b = c.bullet {
                            nextNode.bullet?.addToChildren(b)
                        }
                    }

                    node.delete()
                    node = nextNode

                    cursorPosition = node.text.count
                    nextNode.text.append(remainingText)
                }
            } else {
                cursorPosition = node.position(before: cursorPosition)
                node.text.remove(at: node.text.index(at: cursorPosition))
            }
        }
        cancelSelection()
    }

    func insertNewline() {
        if !selectedTextRange.isEmpty {
            node.text.removeSubrange(node.text.range(from: selectedTextRange))
            node.text.insert("\n", at: node.text.index(at: selectedTextRange.startIndex))
            cursorPosition = node.position(after: selectedTextRange.startIndex)
            if cursorPosition == NSNotFound {
                cursorPosition = node.text.count
            }
            cancelSelection()
        } else if cursorPosition != 0 && node.text.count != 0 {
            node.text.insert("\n", at: node.text.index(at: cursorPosition))
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

        node.text.replaceSubrange(node.text.range(from: range), with: string)
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

        let r = node.text.range(from: range)
        node.text.replaceSubrange(r, with: string)
        cursorPosition = range.lowerBound + c
        cancelSelection()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        let r1 = rectAt(range.lowerBound)
        let r2 = rectAt(range.upperBound)
        return (r1.union(r2), range)
    }
}
