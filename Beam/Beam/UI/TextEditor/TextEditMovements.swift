//
//  TextEditMovements.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation

extension TextRoot {
    func moveLeft() {
        if selectedTextRange.isEmpty {
            if cursorPosition == 0 {
                if let next = node.previousVisible() {
                    node.invalidateTextRendering()
                    node = next
                    cursorPosition = node.text.count
                } else {
                    cursorPosition = 0
                }
            } else {
                cursorPosition = node.position(before: cursorPosition)
            }
        }
        cancelSelection()
        node.invalidateTextRendering()
    }

    func moveRight() {
        if selectedTextRange.isEmpty {
            if cursorPosition == node.text.count {
                if let next = node.nextVisible() {
                    node.invalidateTextRendering()
                    node = next
                    cursorPosition = 0
                }
            } else {
                cursorPosition = node.position(after: cursorPosition)
            }
        }
        cancelSelection()
        node.invalidateTextRendering()
    }

    func moveLeftAndModifySelection() {
        if cursorPosition != 0 {
            let newCursorPosition = node.position(before: cursorPosition)
            if cursorPosition == selectedTextRange.lowerBound {
                selectedTextRange = node.text.clamp(newCursorPosition..<selectedTextRange.upperBound)
            } else {
                selectedTextRange = node.text.clamp(selectedTextRange.lowerBound..<newCursorPosition)
            }
            cursorPosition = newCursorPosition
            node.invalidateTextRendering()
        }
    }

    func moveWordRight() {
        node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            self.cursorPosition = self.node.position(at: r1.upperBound)
            stop = true
        }
        cancelSelection()
        node.invalidateTextRendering()
    }

    func moveWordLeft() {
        var range = node.text.startIndex ..< node.text.endIndex
        node.text.enumerateSubstrings(in: node.text.startIndex..<node.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        let pos = node.position(at: range.lowerBound)
        cursorPosition = pos == cursorPosition ? 0 : pos
        cancelSelection()
        node.invalidateTextRendering()
    }

    func moveWordRightAndModifySelection() {
        var newCursorPosition = cursorPosition
        node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            newCursorPosition = self.node.position(at: r1.upperBound)
            stop = true
        }
        extendSelection(to: newCursorPosition)
        node.invalidateTextRendering()
    }

    //swiftlint:disable cyclomatic_complexity function_body_length
    func moveWordLeftAndModifySelection() {
        var range = node.text.startIndex ..< node.text.endIndex
        let newCursorPosition = cursorPosition
        node.text.enumerateSubstrings(in: node.text.startIndex..<node.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        let pos = node.position(at: range.lowerBound)
        cursorPosition = pos == cursorPosition ? 0 : pos
        extendSelection(to: newCursorPosition)
        node.invalidateTextRendering()
    }

    func moveRightAndModifySelection() {
        if cursorPosition != node.text.count {
            extendSelection(to: node.position(after: cursorPosition))
        }
        node.invalidateTextRendering()
    }

    func moveToBeginningOfLine() {
        cursorPosition = node.beginningOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToEndOfLine() {
        cursorPosition = node.endOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToBeginningOfLineAndModifySelection() {
        extendSelection(to: node.beginningOfLineFromPosition(cursorPosition))
        node.invalidateTextRendering()
    }

    func moveToEndOfLineAndModifySelection() {
        extendSelection(to: node.endOfLineFromPosition(cursorPosition))
        node.invalidateTextRendering()
    }

    func moveUp() {
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisible() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnLastLine(atOffset: offset)
                node.invalidateTextRendering()
                node = newNode
            } else {
                cursorPosition = 0
            }
        } else {
            cursorPosition = node.positionAbove(cursorPosition)
        }
        cancelSelection()
        node.invalidateTextRendering()
    }

    func moveDown() {
        if node.isOnLastLine(cursorPosition) {
            if let newNode = node.nextVisible() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnFirstLine(atOffset: offset)
                node.invalidateTextRendering()
                node = newNode
            } else {
                cursorPosition = node.text.count
            }
        } else {
            cursorPosition = node.positionBelow(cursorPosition)
        }
        cancelSelection()
        node.invalidateTextRendering()
    }

    public func cancelSelection() {
        selectedTextRange = cursorPosition..<cursorPosition
        markedTextRange = selectedTextRange
        invalidate()
    }

    public func selectAll() {
        selectedTextRange = node.text.wholeRange
        cursorPosition = selectedTextRange.upperBound
        invalidate()
        node.invalidateTextRendering()
    }

    public func moveUpAndModifySelection() {
        extendSelection(to: node.positionAbove(cursorPosition))
        node.invalidateTextRendering()
    }

    public func moveDownAndModifySelection() {
        extendSelection(to: node.positionBelow(cursorPosition))
        node.invalidateTextRendering()
    }

    public func extendSelection(to newCursorPosition: Int) {
        var r1 = selectedTextRange.lowerBound
        var r2 = selectedTextRange.upperBound
        if cursorPosition == r2 {
            r2 = newCursorPosition
        } else {
            r1 = newCursorPosition
        }
        if r1 < r2 {
            selectedTextRange = node.text.clamp(r1..<r2)
        } else {
            selectedTextRange = node.text.clamp(r2..<r1)
        }
        cursorPosition = newCursorPosition
        invalidate()
    }
}
