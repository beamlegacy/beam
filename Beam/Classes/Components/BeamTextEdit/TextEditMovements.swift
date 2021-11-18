//swiftlint:disable file_length
import Foundation

public enum CursorPositionAfterSelection {
    case start, end, current
}

extension TextRoot {
    func moveLeft() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == 0 {
                if let next = node.previousVisibleNode(ElementNode.self),
                   canMove(from: node, to: next) {
                    node.invalidateText()
                    next.focus(position: next.textCount)
                } else {
                    cursorPosition = 0
                }
            } else {
                // we allow to step "on" an uneditable range once
                let isInsideUneditableRange = (node as? TextNode)?.isCursorInsideUneditableRange(caretIndex: caretIndex)
                caretIndex = node.position(before: caretIndex, avoidUneditableRange: isInsideUneditableRange ?? true)
            }
        }
        cancelSelection(.start)
        node.invalidateText()
    }

    func moveRight() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if selectedTextRange.isEmpty {
            if cursorPosition == node.textCount {
                if let next = node.nextVisibleNode(ElementNode.self),
                   canMove(from: node, to: next) {
                    node.invalidateText()
                    next.focus()
                }
            } else {
                // we allow to step "on" an uneditable range once
                let isInsideUneditableRange = (node as? TextNode)?.isCursorInsideUneditableRange(caretIndex: caretIndex)
                caretIndex = node.position(after: caretIndex, avoidUneditableRange: isInsideUneditableRange ?? true)
            }
        }
        cancelSelection(.end)
        node.invalidateText()
    }

    func moveLeftAndModifySelection() {
        guard root?.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              cursorPosition != 0
        else {
            extendNodeSelectionUp()
            editor?.hideInlineFormatter()
            return
        }

        let newCaretIndex = node.position(before: caretIndex, avoidUneditableRange: true)
        let newCursorPosition = node.caretAtIndex(newCaretIndex).positionInSource
        extendSelection(to: newCursorPosition)
        caretIndex = newCaretIndex
        node.invalidateText()
    }

    func moveRightAndModifySelection() {
        guard root?.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              cursorPosition != node.textCount
        else {
            extendNodeSelectionDown()
            editor?.hideInlineFormatter()
            return
        }

        let newCaretIndex = node.position(after: caretIndex, avoidUneditableRange: true)
        let newCursorPosition = node.caretAtIndex(newCaretIndex).positionInSource
        extendSelection(to: newCursorPosition)
        caretIndex = newCaretIndex
        node.invalidateText()
    }

    func moveWordRight() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode,
              node.textCount != cursorPosition
        else {
            if focusedWidget as? ElementNode != nil {
                moveRight()
            }
            return
        }
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
        cancelSelection(.end)
        node.invalidateText()
    }

    func moveWordLeft() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode,
              cursorPosition != 0
        else {
            if focusedWidget as? ElementNode != nil {
                moveLeft()
            }
            return
        }
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
        cancelSelection(.start)
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

    func moveToBeginningOfLine() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        cursorPosition = node.beginningOfLineFromPosition(cursorPosition)
        cancelSelection(.start)
    }

    func moveToEndOfLine() {
        cancelNodeSelection()
        guard let node = focusedWidget as? TextNode else { return }
        cursorPosition = node.endOfLineFromPosition(cursorPosition)
        cancelSelection(.end)
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

    func moveToBeginningOfDocument() {
        root?.firstVisibleNode(ElementNode.self)?.focus()
    }

    func moveToEndOfDocument() {
        guard let lastNode = root?.lastVisibleNode(TextNode.self) else { return }
        cursorPosition = lastNode.endOfLineFromPosition(lastNode.indexOnLastLine(atOffset: 0))
        lastNode.focus(position: cursorPosition)
    }

    func moveUp() {
        cancelNodeSelection()
        guard let node = focusedWidget as? ElementNode else { return }
        if node.isOnFirstLine(cursorPosition) {
            if let newNode = node.previousVisibleNode(ElementNode.self),
               canMove(from: node, to: newNode) {
                let offset = node.offsetAt(index: cursorPosition) + node.offsetInDocument.x - newNode.offsetInDocument.x
                node.invalidateText()
                newNode.focus(position: newNode.indexOnLastLine(atOffset: offset))
            } else {
                cursorPosition = 0
                if !(editor?.journalMode ?? true) {
                    editor?.scroll(.zero)
                }
            }
        } else {
            var _caretIndex = node.caretAbove(caretIndex)
            if let node = focusedWidget as? TextNode,
               let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(_caretIndex, after: false) {
                _caretIndex = updatedCaretIndex
            }
            self.caretIndex = _caretIndex
        }
        cancelSelection(.start)
        node.invalidateText()
    }

    func moveDown() {
        cancelNodeSelection()

        guard let node = focusedWidget as? ElementNode else { return }
        if node.isOnLastLine(cursorPosition) {
            if !moveToNextNodeIfPossible(fromNode: node, cursor: cursorPosition) {
                cursorPosition = node.textCount
            }
        } else {
            var _caretIndex = node.caretBelow(caretIndex)
            if let updatedCaretIndex = node.caretIndexAvoidingUneditableRange(_caretIndex, after: true) {
                _caretIndex = updatedCaretIndex

                let isLastCaret = _caretIndex == node.caretIndexForSourcePosition(node.textCount)
                if !isLastCaret || !moveToNextNodeIfPossible(fromNode: node, cursor: cursorPosition) {
                    self.caretIndex = _caretIndex
                }
            } else {
                self.caretIndex = _caretIndex
            }
        }
        cancelSelection(.end)
        node.invalidateText()
    }

    private func moveToNextNodeIfPossible(fromNode node: ElementNode, cursor: Int) -> Bool {
        guard let newNode = node.nextVisibleNode(ElementNode.self),
        self.canMove(from: node, to: newNode) else { return false }
        let offset = node.offsetAt(index: cursor) + node.offsetInDocument.x - newNode.offsetInDocument.x
        node.invalidateText()
        newNode.focus(position: newNode.indexOnFirstLine(atOffset: offset))
        return true
    }

    private func canMove(from currentNode: ElementNode, to newNode: ElementNode) -> Bool {
        if !(newNode is ProxyNode) && !(currentNode is ProxyNode) ||
            (newNode is ProxyNode) && (currentNode is ProxyNode) {
            return true
        } else if newNode.parent == currentNode || currentNode.parent == newNode {
            return true
        }
        return false
    }

    public func cancelSelection(_ position: CursorPositionAfterSelection) {
        switch position {
        case .current:
            break
        case .start:
            cursorPosition = selectedTextRange.startIndex
        case .end:
            cursorPosition = selectedTextRange.endIndex
        }

        selectedTextRange = cursorPosition..<cursorPosition
        unmarkText()
        focusedWidget?.invalidate()
    }

    @discardableResult
    public func selectAllNodes(force: Bool = false) -> Bool {
        let alreadySelectingNodes = root?.state.nodeSelection != nil
        guard let selection = startNodeSelection() else { return false }

        // If we are starting the selection we need to bail out now: we have just seleted the first node
        guard alreadySelectingNodes || force else { return true }

        if let proxyNodeStart = selection.start as? ProxyNode, selection.isSelectingProxy {
            let parent = proxyNodeStart.highestParent()
            selection.append(parent)
            selection.appendChildren(of: parent)
            selection.start = parent
            selection.end = parent.deepestElementNodeChild()
        } else if let parent = root, !selection.isSelectingProxy {
            selection.append(parent)
            selection.appendChildren(of: parent)
            selection.start = parent
            selection.end = parent.deepestElementNodeChild()
        }
        return true
    }

    @discardableResult
    public func selectAllNodesHierarchically() -> Bool {
        guard let selection = root?.state.nodeSelection else {
            _ = startNodeSelection()
            return true
        }

        if !selection.start.areAllChildrenSelected {
            selection.appendChildren(of: selection.start)
            return true
        }

        guard let parent = selection.start.parent as? ElementNode else { return false }
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
        selectAllText()
    }

    public func selectAllText() {
        textIsSelected = true
        guard root?.state.nodeSelection == nil else {
            _ = selectAllNodes()
            return
        }
        guard let node = focusedWidget as? TextNode,
              selectedTextRange != node.text.wholeRange
        else {
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
            editor?.hideInlineFormatter()
            return
        }

        guard let node = focusedWidget as? ElementNode else { return }
        if cursorPosition == 0 {
            extendNodeSelectionUp()
        } else {
            extendSelection(to: node.positionForCaretIndex(node.caretAbove(caretIndex)))
        }
        node.invalidateText()
    }

    public func moveDownAndModifySelection() {
        guard root?.state.nodeSelection == nil else {
            extendNodeSelectionDown()
            editor?.hideInlineFormatter()
            return
        }

        guard let node = focusedWidget as? ElementNode else { return }
        if cursorPosition == node.textCount {
            extendNodeSelectionDown()
        } else {
            extendSelection(to: node.positionForCaretIndex(node.caretBelow(caretIndex)))
        }
        node.invalidateText()
    }

    public func extendSelection(to newCursorPosition: Int) {
        guard let node = focusedWidget as? ElementNode else { return }
        var r1 = selectedTextRange.lowerBound
        var r2 = selectedTextRange.upperBound
        if cursorPosition == r2 {
            r2 = newCursorPosition
        } else {
            r1 = newCursorPosition
        }
        if r1 < r2 {
            selectedTextRange = node.clampTextRange(r1..<r2)
        } else {
            selectedTextRange = node.clampTextRange(r2..<r1)
        }
        cursorPosition = newCursorPosition
        node.invalidate()
    }

    func extendNodeSelectionUp() {
        if let selection = root?.state.nodeSelection {
            selection.extendUp()
            editor?.setHotSpotToNode(selection.end)
        } else {
            _ = startNodeSelection()
        }
    }

    func extendNodeSelectionDown() {
        if let selection = root?.state.nodeSelection {
            selection.extendDown()
            editor?.setHotSpotToNode(selection.end)
        } else {
            _ = startNodeSelection()
        }
    }

    func startNodeSelection() -> NodeSelection? {
        if let selection = root?.state.nodeSelection {
            return selection
        }
        guard let node = focusedWidget as? ElementNode else { return nil }
        if let textNode = node as? TextNode {
            textNode.updateActionLayerVisibility(hidden: true)
        }

        let selection = NodeSelection(start: node, end: node)
        root?.state.nodeSelection = selection
        cancelSelection(.current)
        return selection
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
