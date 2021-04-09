//
//  TextEditMovements.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

import Foundation

extension TextRoot {
    func moveLeft() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == 0 {
                if let next = node.previousVisibleTextNode() {
                    node.invalidateText()
                    next.focus(cursorPosition: node.text.count)
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
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == node.text.count {
                if let next = node.nextVisibleTextNode() {
                    node.invalidateText()
                    next.focus()
                }
            } else {
                cursorPosition = node.position(after: cursorPosition)
            }
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveLeftAndModifySelection() {
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
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
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        node.text.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            self.cursorPosition = node.position(at: r1.upperBound)
            stop = true
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveWordLeft() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
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
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
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
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
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
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        if cursorPosition != node.text.count {
            extendSelection(to: node.position(after: cursorPosition))
        }
        node.invalidateText()
    }

    func moveToBeginningOfLine() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        cursorPosition = node.beginningOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToEndOfLine() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        cursorPosition = node.endOfLineFromPosition(cursorPosition)
        cancelSelection()
    }

    func moveToBeginningOfLineAndModifySelection() {
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        extendSelection(to: node.beginningOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveToEndOfLineAndModifySelection() {
        guard root.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        extendSelection(to: node.endOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveUp() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisibleTextNode() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                node.invalidateText()
                newNode.focus(cursorPosition: newNode.indexOnLastLine(atOffset: offset))
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
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        if node.isOnLastLine(cursorPosition) {
            if let newNode = node.nextVisibleTextNode() {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                node.invalidateText()
                newNode.focus(cursorPosition: newNode.indexOnFirstLine(atOffset: offset))
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
        unmarkText()
        focusedWidget?.invalidate()
    }

    @discardableResult
    public func selectAllNodes() -> Bool {
        guard let selection = root.state.nodeSelection else {
            startNodeSelection()
            return true
        }

        let parent = root
        selection.append(parent)
        selection.appendChildren(of: parent)
        selection.start = parent
        selection.end = parent.deepestTextNodeChild()
        return true
    }

    @discardableResult
    public func selectAllNodesHierarchically() -> Bool {
        guard let selection = root.state.nodeSelection else {
            startNodeSelection()
            return true
        }

        if !selection.start.areAllChildrenSelected {
            selection.appendChildren(of: selection.start)
            return true
        }

        guard let parent = selection.start.parent as? TextNode else { return false }
        if !parent.selected {
            selection.append(parent)
            selection.appendChildren(of: parent)
            selection.start = parent
            selection.end = parent.deepestTextNodeChild()
            return true
        }
        return false
    }

    public func selectAll() {
        textIsSelected = true
        _ = selectAllNodes()
    }

    public func selectAllText() {
        textIsSelected = true
        guard root.state.nodeSelection == nil else {
            _ = selectAllNodes()
            return
        }
        guard let node = focusedWidget as? TextNode else { return }
        guard selectedTextRange != node.text.wholeRange else {
            _ = selectAllNodes()
            return
        }

        selectedTextRange = node.text.wholeRange
        cursorPosition = selectedTextRange.upperBound
        node.invalidate()
        node.invalidateText()
    }

    public func moveUpAndModifySelection() {
        guard root.state.nodeSelection == nil else {
            extendNodeSelectionUp()
            return
        }

        guard let node = focusedWidget as? TextNode else { return }
        if cursorPosition == 0 {
            extendNodeSelectionUp()
        } else {
            extendSelection(to: node.positionAbove(cursorPosition))
        }
        node.invalidateText()
    }

    public func moveDownAndModifySelection() {
        guard root.state.nodeSelection == nil else {
            extendNodeSelectionDown()
            return
        }

        guard let node = focusedWidget as? TextNode else { return }
        if cursorPosition == node.text.text.count {
            extendNodeSelectionDown()
        } else {
            extendSelection(to: node.positionBelow(cursorPosition))
        }
        node.invalidateText()
    }

    public func extendSelection(to newCursorPosition: Int) {
        guard let node = focusedWidget as? TextNode else { return }
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

    func extendNodeSelectionUp() {
        if let selection = root.state.nodeSelection {
            selection.extendUp()
            editor.setHotSpotToNode(selection.end)
        } else {
            startNodeSelection()
        }
    }

    func extendNodeSelectionDown() {
        if let selection = root.state.nodeSelection {
            selection.extendDown()
            editor.setHotSpotToNode(selection.end)
        } else {
            startNodeSelection()
        }
    }

    func startNodeSelection() {
        guard let node = focusedWidget as? TextNode else { return }
        root.state.nodeSelection = NodeSelection(start: node, end: node)
        cancelSelection()
    }

    func cancelNodeSelection() {
        guard let selection = root.state.nodeSelection else { return }
        selection.end.focus()
        root.state.nodeSelection = nil
    }

    func wordSelection(from pos: Int) {
        guard let node = focusedWidget as? TextNode else { return }
        let str = node.text.text
        let index = str.index(str.startIndex, offsetBy: pos)
        str.enumerateSubstrings(in: str.startIndex..<str.endIndex, options: .byWords) { [self] (_, r1, _, stop) in
            if r1.contains(index) {
                self.selectedTextRange = str.position(at: r1.lowerBound)..<str.position(at: r1.upperBound)
                cursorPosition = self.selectedTextRange.upperBound
                stop = true
            }
        }
    }
}
