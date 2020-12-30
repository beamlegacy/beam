//
//  TextEditMovements.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation

extension TextRoot {
    func moveLeft() {
        guard let node = node as? TextNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == 0 {
                if let next = node.previousVisible() {
                    node.invalidateText()
                    self.node = next
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
        guard let node = node as? TextNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == node.text.count {
                if let next = node.nextVisible() {
                    node.invalidateText()
                    self.node = next
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
        guard let node = node as? TextNode else { return }
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
        guard let node = node as? TextNode else { return }
        node.text.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            self.cursorPosition = node.position(at: r1.upperBound)
            stop = true
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveWordLeft() {
        guard let node = node as? TextNode else { return }
        var range = node.text.text.startIndex ..< node.text.text.endIndex
        node.text.text.enumerateSubstrings(in: node.text.text.startIndex..<node.text.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        let pos = node.position(at: range.lowerBound)
        cursorPosition = pos == cursorPosition ? 0 : pos
        cancelSelection()
        node.invalidateText()
    }

    func moveWordRightAndModifySelection() {
        guard let node = node as? TextNode else { return }
        var newCursorPosition = cursorPosition
        node.text.text.enumerateSubstrings(in: node.text.text.index(at: cursorPosition)..<node.text.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            newCursorPosition = node.position(at: r1.upperBound)
            stop = true
        }
        extendSelection(to: newCursorPosition)
        node.invalidateText()
    }

    //swiftlint:disable cyclomatic_complexity function_body_length
    func moveWordLeftAndModifySelection() {
        guard let node = node as? TextNode else { return }
        var range = node.text.text.startIndex ..< node.text.text.endIndex
        node.text.text.enumerateSubstrings(in: node.text.text.startIndex..<node.text.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        let pos = node.position(at: range.lowerBound)
        let newCursorPosition = pos == cursorPosition ? 0 : pos
        extendSelection(to: newCursorPosition)
        node.invalidateText()
    }

    func moveRightAndModifySelection() {
        guard let node = node as? TextNode else { return }
        if cursorPosition != node.text.count {
            extendSelection(to: node.position(after: cursorPosition))
        }
        node.invalidateText()
    }

    func moveToBeginningOfLine() {
        guard let node = node as? TextNode else { return }
        cursorPosition = node.beginningOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToEndOfLine() {
        guard let node = node as? TextNode else { return }
        cursorPosition = node.endOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToBeginningOfLineAndModifySelection() {
        guard let node = node as? TextNode else { return }
        extendSelection(to: node.beginningOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveToEndOfLineAndModifySelection() {
        guard let node = node as? TextNode else { return }
        extendSelection(to: node.endOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveUp() {
        guard let node = node as? TextNode else { return }
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisible() as? TextNode {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnLastLine(atOffset: offset)
                node.invalidateText()
                self.node = newNode
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
        guard let node = node as? TextNode else { return }
        if node.isOnLastLine(cursorPosition) {
            if let newNode = node.nextVisible() as? TextNode {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                cursorPosition = newNode.indexOnFirstLine(atOffset: offset)
                node.invalidateText()
                self.node = newNode
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
        node.invalidate()
    }

    public func selectAll() {
        guard let node = node as? TextNode else { return }
        selectedTextRange = node.text.wholeRange
        cursorPosition = selectedTextRange.upperBound
        node.invalidate()
        node.invalidateText()
    }

    public func moveUpAndModifySelection() {
        guard let node = node as? TextNode else { return }
        extendSelection(to: node.positionAbove(cursorPosition))
        node.invalidateText()
    }

    public func moveDownAndModifySelection() {
        guard let node = node as? TextNode else { return }
        extendSelection(to: node.positionBelow(cursorPosition))
        node.invalidateText()
    }

    public func extendSelection(to newCursorPosition: Int) {
        guard let node = node as? TextNode else { return }
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
        node.invalidate()
    }
}
