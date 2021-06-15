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
        guard let node = focusedWidget as? ElementNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == 0 {
                if let next = node.previousVisibleNode(ElementNode.self) {
                    node.invalidateText()
                    next.focus(position: next.textCount)
                } else {
                    cursorPosition = 0
                }
            } else {
                caretIndex = node.position(before: caretIndex, avoidUneditableRange: true)
            }
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveRight() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == node.textCount {
                if let next = node.nextVisibleNode(ElementNode.self) {
                    node.invalidateText()
                    next.focus()
                }
            } else {
                caretIndex = node.position(after: caretIndex, avoidUneditableRange: true)
            }
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveLeftAndModifySelection() {
        guard root?.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              cursorPosition != 0
        else { return }
        let newCaretIndex = node.position(before: caretIndex, avoidUneditableRange: true)
        let newCursorPosition = node.caretAtIndex(newCaretIndex).positionInSource
        extendSelection(to: newCursorPosition)
        caretIndex = newCaretIndex
        node.invalidateText()
    }

    func moveWordRight() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        var pos = cursorPosition
        node.text.text.enumerateSubstrings(in: node.text.index(at: cursorPosition)..<node.text.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            pos = node.position(at: r1.upperBound)
            stop = true
        }
        if let caretIndex = node.caretIndexForSourcePosition(pos),
           let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(caretIndex, after: true) {
            pos = node.caretAtIndex(updatedCaretIndex).positionOnScreen
        }
        cursorPosition = pos
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
        var pos = node.position(at: range.lowerBound)
        if let caretIndex = node.caretIndexForSourcePosition(pos),
           let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(caretIndex, after: false) {
            pos = node.caretAtIndex(updatedCaretIndex).positionOnScreen
        }
        cursorPosition = pos == cursorPosition ? 0 : pos
        cancelSelection()
        node.invalidateText()
    }

    func moveWordRightAndModifySelection() {
        guard root?.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        var newCursorPosition = cursorPosition
        node.text.text.enumerateSubstrings(in: node.text.text.index(at: cursorPosition)..<node.text.text.endIndex, options: .byWords) { (_, r1, _, stop) in
            newCursorPosition = node.position(at: r1.upperBound)
            stop = true
        }
        if let caretIndex = node.caretIndexForSourcePosition(newCursorPosition),
           let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(caretIndex, after: true) {
            newCursorPosition = node.caretAtIndex(updatedCaretIndex).positionOnScreen
        }
        extendSelection(to: newCursorPosition)
        node.invalidateText()
    }

    //swiftlint:disable cyclomatic_complexity function_body_length
    func moveWordLeftAndModifySelection() {
        guard root?.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        var range = node.text.text.startIndex ..< node.text.text.endIndex
        node.text.text.enumerateSubstrings(in: node.text.text.startIndex..<node.text.text.index(at: cursorPosition), options: .byWords) { (_, r1, _, _) in
            range = r1
        }
        var pos = node.position(at: range.lowerBound)
        if let caretIndex = node.caretIndexForSourcePosition(pos),
           let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(caretIndex, after: false) {
            pos = node.caretAtIndex(updatedCaretIndex).positionOnScreen
        }
        let newCursorPosition = pos == cursorPosition ? 0 : pos
        extendSelection(to: newCursorPosition)
        node.invalidateText()
    }

    func moveRightAndModifySelection() {
        guard root?.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              cursorPosition != node.text.count
        else { return }
        let newCaretIndex = node.position(after: caretIndex, avoidUneditableRange: true)
        let newCursorPosition = node.caretAtIndex(newCaretIndex).positionInSource
        extendSelection(to: newCursorPosition)
        caretIndex = newCaretIndex
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
        guard root?.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        extendSelection(to: node.beginningOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveToEndOfLineAndModifySelection() {
        guard root?.state.nodeSelection == nil else { return }
        guard let node = focusedWidget as? TextNode else { return }
        extendSelection(to: node.endOfLineFromPosition(cursorPosition))
        node.invalidateText()
    }

    func moveUp() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisibleNode(ElementNode.self) {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                node.invalidateText()
                newNode.focus(position: newNode.indexOnLastLine(atOffset: offset))
            } else {
                cursorPosition = 0
                if !editor.journalMode {
                    editor.scroll(.zero)
                }
            }
        } else {
            cursorPosition = node.positionAbove(cursorPosition)
        }
        cancelSelection()
        node.invalidateText()
    }

    func moveDown() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if node.isOnLastLine(cursorPosition) {
            if let newNode = node.nextVisibleNode(ElementNode.self) {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                node.invalidateText()
                newNode.focus(position: newNode.indexOnFirstLine(atOffset: offset))
            } else {
                guard let node = focusedWidget as? TextNode else { return }
                cursorPosition = node.text.count
            }
        } else {
            guard let node = focusedWidget as? TextNode else { return }
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
        guard let selection = root?.state.nodeSelection else {
            startNodeSelection()
            return true
        }

        if let proxyNodeStart = selection.start as? ProxyNode, selection.isSelectingProxy {
            let parent = proxyNodeStart.highestParent()
            selection.append(parent)
            selection.appendChildren(of: parent)
            selection.start = parent
            selection.end = parent.deepestElementNodeChild()
        } else if let parent = root, !selection.isSelectingProxy {
            selection.appendChildren(of: parent)
            selection.start = parent
            selection.end = parent.deepestElementNodeChild()
        }
        return true
    }

    @discardableResult
    public func selectAllNodesHierarchically() -> Bool {
        guard let selection = root?.state.nodeSelection else {
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
            selection.end = parent.deepestElementNodeChild()
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
        guard root?.state.nodeSelection == nil else {
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
        guard root?.state.nodeSelection == nil else {
            extendNodeSelectionUp()
            editor.hideInlineFormatter()
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
        guard root?.state.nodeSelection == nil else {
            extendNodeSelectionDown()
            editor.hideInlineFormatter()
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
        if let selection = root?.state.nodeSelection {
            selection.extendUp()
            editor.setHotSpotToNode(selection.end)
        } else {
            startNodeSelection()
        }
    }

    func extendNodeSelectionDown() {
        if let selection = root?.state.nodeSelection {
            selection.extendDown()
            editor.setHotSpotToNode(selection.end)
        } else {
            startNodeSelection()
        }
    }

    func startNodeSelection() {
        guard let node = focusedWidget as? TextNode,
              node.placeholder.isEmpty || !node.text.isEmpty else { return }
        node.updateActionLayerVisibility(hidden: true)
        root?.state.nodeSelection = NodeSelection(start: node, end: node)
        cancelSelection()
    }

    func cancelNodeSelection() {
        guard let selection = root?.state.nodeSelection else { return }
        selection.end.focus()
        root?.state.nodeSelection = nil
    }

    func wordSelection(from pos: Int) {
        guard let node = focusedWidget as? TextNode else { return }
        let str = node.text.text
        guard str.count >= pos else { return }
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
