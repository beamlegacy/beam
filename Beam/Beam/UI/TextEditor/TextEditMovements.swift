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
                    node.invalidateText()
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
        node.invalidateText()
    }

    func moveRight() {
        if selectedTextRange.isEmpty {
            if cursorPosition == node.text.count {
                if let next = node.nextVisible() {
                    node.invalidateText()
                    node = next
                    cursorPosition = 0
                }
            } else {
                cursorPosition = node.position(after: cursorPosition)
            }
        }
        cancelSelection()
        node.invalidateText()
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
            node.invalidateText()
        }
    }

    func moveWordRight() {
        node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            self.cursorPosition = self.node.position(at: r1.upperBound)
            stop = true
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveWordLeft() {
        var range = node.text.startIndex ..< node.text.endIndex
        node.text.enumerateSubstrings(in: node.text.startIndex..<node.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        let pos = node.position(at: range.lowerBound)
        cursorPosition = pos == cursorPosition ? 0 : pos
        cancelSelection()
        node.invalidateText()
    }

    func moveWordRightAndModifySelection() {
        var newCursorPosition = cursorPosition
        node.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            newCursorPosition = self.node.position(at: r1.upperBound)
            stop = true
        }
        extendSelection(to: newCursorPosition)
        node.invalidateText()
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
        node.invalidateText()
    }

    func moveRightAndModifySelection() {
        if cursorPosition != node.text.count {
            extendSelection(to: node.position(after: cursorPosition))
        }
        node.invalidateText()
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
        node.invalidateText()
    }

    func moveToEndOfLineAndModifySelection() {
        extendSelection(to: node.endOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveUp() {
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisible() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnLastLine(atOffset: offset)
                node.invalidateText()
                node = newNode
            } else {
                cursorPosition = 0
            }
        } else {
            cursorPosition = node.positionAbove(cursorPosition)
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveDown() {
        if node.isOnLastLine(cursorPosition) {
            if let newNode = node.nextVisible() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnFirstLine(atOffset: offset)
                node.invalidateText()
                node = newNode
            } else {
                cursorPosition = node.text.count
            }
        } else {
            cursorPosition = node.positionBelow(cursorPosition)
        }
        cancelSelection()
        node.invalidateText()
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
        node.invalidateText()
    }

    public func moveUpAndModifySelection() {
        extendSelection(to: node.positionAbove(cursorPosition))
        node.invalidateText()
    }

    public func moveDownAndModifySelection() {
        extendSelection(to: node.positionBelow(cursorPosition))
        node.invalidateText()
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
