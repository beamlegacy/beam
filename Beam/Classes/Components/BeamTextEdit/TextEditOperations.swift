//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

//TODO: [Seb] create an abstraction for UndoManager to be able to handle faillures and not register empty undo operations. Then replace all _ with the real test

import Foundation
import BeamCore

// swiftlint:disable file_length

public extension BeamElement {
    var treeDepth: Int {
        return (children.map({ child -> Int in
            child.treeDepth + 1
        }).max() ?? 0)
    }
    var canIncreaseIndentation: Bool {
        return depth + treeDepth < 10
    }
}
extension TextRoot {
    var cmdContext: Widget {
        editor.focusedWidget ?? editor.rootNode
    }

    func increaseNodeIndentation(_ node: ElementNode) -> Bool {
        guard !node.readOnly,
              node.element.canIncreaseIndentation,
              !(node.parent?.isTreeBoundary ?? false),
              let newParent = node.previousSibbling() as? ElementNode
        else { return false }
        return cmdManager.reparentElement(node, to: newParent, atIndex: newParent.element.children.count)
    }

    func decreaseNodeIndentation(_ node: ElementNode) -> Bool {
        guard !node.readOnly,
              !(node.parent?.isTreeBoundary ?? false),
              !(node.parent?.parent?.isTreeBoundary ?? false),
              let prevParent = node.displayedElement.parent,
              let newParent = prevParent.parent,
              let parentIndexInParent = newParent.id == node.elementId ? node.displayedElement.children.count : prevParent.indexInParent
        else { return false }

        return cmdManager.reparentElement(node.element, to: newParent, atIndex: parentIndexInParent + 1)
    }

    func increaseNodeSelectionIndentation() {
        guard let selection = root?.state.nodeSelection else { return }

        root?.note?.cmdManager.beginGroup(with: "IncreaseIndentationGroup")
        for node in selection.sortedRoots {
            _ = increaseNodeIndentation(node)
        }
        root?.note?.cmdManager.endGroup()
    }

    func decreaseNodeSelectionIndentation() {
        guard let selection = root?.state.nodeSelection else { return }

        root?.note?.cmdManager.beginGroup(with: "DecreaseIndentationGroup")
        for node in selection.sortedRoots.reversed() {
            _ = decreaseNodeIndentation(node)
        }
        root?.note?.cmdManager.endGroup()
    }

    func increaseIndentation() {
        guard root?.state.nodeSelection == nil else {
            increaseNodeSelectionIndentation()
            return
        }
        guard let node = focusedWidget as? ElementNode else { return }
        _ = increaseNodeIndentation(node)
    }

    func decreaseIndentation() {
        guard root?.state.nodeSelection == nil else {
            decreaseNodeSelectionIndentation()
            return
        }
        guard let node = focusedWidget as? ElementNode else { return }
        _ = decreaseNodeIndentation(node)
    }

    // swiftlint:disable:next cyclomatic_complexity
    @discardableResult func eraseNodeSelection(createEmptyNodeInPlace: Bool, createNodeInEmptyParent: Bool = true) -> BeamElement? {
        guard let selection = root?.state.nodeSelection else { return nil }
        let sortedNodes = selection.sortedNodes

        // This will be used to create an empty node in place:
        guard let firstParent = sortedNodes.first?.parent as? ElementNode ?? root else { return nil }

        cancelNodeSelection()

        root?.note?.cmdManager.beginGroup(with: "Delete selected nodes")
        defer { root?.note?.cmdManager.endGroup() }

        if let prevWidget = sortedNodes.first?.previousVisibleNode(ElementNode.self) {
            cmdManager.focusElement(prevWidget, cursorPosition: prevWidget.textCount)
        } else if let nextVisibleNode = sortedNodes.last?.nextVisibleNode(ElementNode.self) {
            if (nextVisibleNode as? ProxyTextNode) == nil {
                cmdManager.focusElement(nextVisibleNode, cursorPosition: 0)
            }
        }

        for node in sortedNodes.reversed() {
            // reparent children to previous sibbling or existing parent
            let unproxied = node.unproxyElement
            if let oldIndexInParent = unproxied.indexInParent,
               let newParent = unproxied.previousSibbling() ?? unproxied.parent {
                for child in node.unproxyElement.children {
                    cmdManager.reparentElement(child, to: newParent, atIndex: oldIndexInParent)
                }
            }

            // Delete Selected Element:
            cmdManager.deleteElement(for: node.unproxyElement)

            // Yeah, this sucks, I know
            if let ref = node as? ProxyTextNode,
               let breadcrumb = ref.parent as? BreadCrumb,
               let bcParent = breadcrumb.parent {
                bcParent.removeChild(breadcrumb)
                if bcParent.children.isEmpty {
                    bcParent.parent?.removeChild(bcParent)
                }
            }
        }

        if createEmptyNodeInPlace || (createNodeInEmptyParent && root?.element.children.isEmpty == true) {
            cmdManager.beginGroup(with: "Insert empty element")
            let newElement = BeamElement()
            cmdManager.insertElement(newElement, inNode: firstParent, afterElement: nil)
            cmdManager.focus(newElement, in: firstParent)
            cmdManager.endGroup()
            if !editor.journalMode {
                editor.scroll(.zero)
            }
            return newElement
        }
        return nil
    }

    func replaceSelection(with str: String) {
        guard let node = focusedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty
        else { return }

        let bText = BeamText(text: str, attributes: root?.state.attributes ?? [])
        cmdManager.beginGroup(with: "Erase selection")
        defer { cmdManager.endGroup() }
        cmdManager.replaceText(in: node, for: selectedTextRange, with: bText)
        cmdManager.cancelSelection(node)
        cmdManager.focusElement(node, cursorPosition: selectedTextRange.lowerBound + bText.count)
    }

    func deleteForward() {
        guard root?.state.nodeSelection == nil else {
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly,
              node.displayedElementNoteTitle != nil else {
            if let node = focusedWidget as? ElementNode {
                cmdManager.beginGroup(with: "Delete forward")
                if let nextVisibleNode = node.nextVisibleNode(ElementNode.self) {
                    cmdManager.focusElement(nextVisibleNode, cursorPosition: 0)
                }
                cmdManager.deleteElement(for: node)
                cmdManager.endGroup()
            }
            return

        }

        if !selectedTextRange.isEmpty || cursorPosition != node.text.count {
            cmdManager.deleteText(in: node, for: rangeToDeleteText(in: node, cursorAt: cursorPosition, forward: true))
        } else {
            // Delete element forward
            cmdManager.beginGroup(with: "Delete forward")
            defer { cmdManager.endGroup() }
            if let nextVisibleNode = node.nextVisibleNode(ElementNode.self) {
                let pos = cursorPosition
                if let nextVisibleNode = nextVisibleNode as? TextNode {
                    cmdManager.replaceText(in: node, for: cursorPosition..<cursorPosition, with: nextVisibleNode.text)
                }
                cmdManager.cancelSelection(node)
                cmdManager.focusElement(node, cursorPosition: pos)
                cmdManager.deleteElement(for: nextVisibleNode)
            }
        }
    }

    func deleteBackward() {
        guard root?.state.nodeSelection == nil else {
            editor.cancelPopover()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? TextNode, !node.readOnly else {
            if let node = focusedWidget as? ElementNode {
                cmdManager.beginGroup(with: "Delete backward")
                if let nextVisibleNode = node.nextVisibleNode(ElementNode.self) {
                    cmdManager.focusElement(nextVisibleNode, cursorPosition: 0)
                }
                cmdManager.deleteElement(for: node.unproxyElement)
                cmdManager.endGroup()
            }
            return
        }

        if cursorPosition == 0, selectedTextRange.isEmpty {
            if node.element == node.element.note?.children.first {
                return // can't erase the first element of the note
            }
            // Delete element backward
            cmdManager.beginGroup(with: "Delete backward")
            defer { cmdManager.endGroup() }
            if let prevVisibleNode = node.previousVisibleNode(ElementNode.self) {
                if let prevVisibleNode = prevVisibleNode as? TextNode {
                    let pos = prevVisibleNode.text.count
                    cmdManager.replaceText(in: prevVisibleNode, for: pos..<pos, with: node.text)
                    cmdManager.focusElement(prevVisibleNode, cursorPosition: pos)
                    for (i, child) in node.displayedElement.children.enumerated() {
                        cmdManager.reparentElement(child, to: prevVisibleNode.displayedElement, atIndex: i)
                    }
                    cmdManager.deleteElement(for: node)
                } else {
                    cmdManager.deleteElement(for: prevVisibleNode)
                }
            }
        } else {
            cmdManager.deleteText(in: node, for: rangeToDeleteText(in: node, cursorAt: cursorPosition, forward: false))
        }
    }

    func rangeToDeleteText(in node: TextNode, cursorAt cursorPos: Int, forward: Bool) -> Range<Int> {
        guard selectedTextRange.isEmpty else {
            return extendRangeWithUneditableRanges(selectedTextRange, in: node)
        }

        let nextUpperBound = forward ? cursorPos + 1 : cursorPos
        if let uneditableRange = node.uneditableRangeAt(index: nextUpperBound) {
            return uneditableRange
        }
        return nextUpperBound - 1 ..< nextUpperBound
    }

    /// extend range to include uneditable ranges that might partially included
    private func extendRangeWithUneditableRanges(_ range: Range<Int>, in node: TextNode) -> Range<Int> {
        var finalRange = range
        if let uneditableRangeAfter = node.uneditableRangeAt(index: finalRange.upperBound),
           uneditableRangeAfter.contains(finalRange.upperBound - 1) {
            finalRange = finalRange.join(uneditableRangeAfter)
        }
        if finalRange.lowerBound != finalRange.upperBound,
           let uneditableRangeBefore = node.uneditableRangeAt(index: finalRange.lowerBound),
           uneditableRangeBefore.contains(finalRange.lowerBound) {
            finalRange = finalRange.join(uneditableRangeBefore)
        }

        return finalRange
    }

    func insertNewline() {
        guard root?.state.nodeSelection == nil,
              let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        if !node.element.text.isEmpty {
            if !selectedTextRange.isEmpty {
                cmdManager.deleteText(in: node, for: selectedTextRange)
            }

            let bText = BeamText(text: "\n", attributes: [])
            cmdManager.inputText(bText, in: node, at: cursorPosition)
        }
    }

    // Text Input from AppKit:
    public func hasMarkedText() -> Bool {
        return markedTextRange != nil
    }

    // Replaces a specified range in the receiver’s text storage with the given string and sets the selection.
    public func setMarkedText(string: String, selectedRange: Range<Int>?, replacementRange: Range<Int>?) {
        //Logger.shared.logDebug("setMarkedText(string: '\(string)', selectedRange: \(String(describing: selectedRange)), replacementRange: \(String(describing: replacementRange))")
        guard let node = focusedWidget as? TextNode,
              !node.readOnly else { return }

        // If there is no marked text, the current selection is replaced. If there is no selection, the string is inserted at the insertion point.
        var rangeToReplace = cursorPosition ..< cursorPosition
        if let markedRange = markedTextRange {
            rangeToReplace = markedRange
        } else if !selectedTextRange.isEmpty {
            rangeToReplace = selectedTextRange.lowerBound ..< selectedTextRange.upperBound
        }

        if let replacementRange = replacementRange {
            let low = rangeToReplace.lowerBound + replacementRange.lowerBound
            let high = low + replacementRange.count
            rangeToReplace = low ..< high
        }

        //Logger.shared.logDebug("   replace sub range \(rangeToReplace) with '\(string)'")
        node.text.replaceSubrange(rangeToReplace, with: string)
        markedTextRange = rangeToReplace.lowerBound ..< rangeToReplace.lowerBound + string.count
        cursorPosition = rangeToReplace.lowerBound + string.count
        if let selectedRange = selectedRange {
            selectedTextRange = rangeToReplace.lowerBound + selectedRange.lowerBound ..< rangeToReplace.lowerBound + selectedRange.lowerBound
        } else {
            selectedTextRange = cursorPosition ..< cursorPosition
        }
        node.invalidateText()
    }

    public func unmarkText() {
        guard let node = focusedWidget as? TextNode, !node.readOnly else { return }
        markedTextRange = nil
        node.invalidateText()
    }

    public func insertText(string: String, replacementRange: Range<Int>?) {
        eraseNodeSelection(createEmptyNodeInPlace: true)
        guard let node = focusedWidget as? TextNode, !node.readOnly
        else {
            guard focusedWidget as? ElementNode != nil else {
                return
            }

            insertElementNearNonTextElement(string)
            return
        }

        var range = cursorPosition..<cursorPosition
        if let r = replacementRange {
            range = r
        } else {
            if let markedRange = markedTextRange {
                range = markedRange
            } else if !selectedTextRange.isEmpty {
                range = selectedTextRange
            }
        }

        range = extendRangeWithUneditableRanges(range, in: node)
        var hasCmdGroup = false
        if !range.isEmpty {
            hasCmdGroup = true
            cmdManager.beginGroup(with: "Insert replacing")
            cmdManager.deleteText(in: node, for: range)
        }

        let bText = BeamText(text: string, attributes: root?.state.attributes ?? [])
        cmdManager.inputText(bText, in: node, at: cursorPosition)
        if hasCmdGroup {
            cmdManager.endGroup()
        }
        cancelSelection()
        unmarkText()
    }

    public func insertText(text: BeamText, replacementRange: Range<Int>?) {
        eraseNodeSelection(createEmptyNodeInPlace: true)
        guard let node = focusedWidget as? TextNode, !node.readOnly
        else {
            guard focusedWidget as? ElementNode != nil else {
                return
            }

            insertElementNearNonTextElement(text)
            return
        }

        var range = cursorPosition..<cursorPosition
        if let r = replacementRange {
            range = r
        } else {
            if let markedRange = markedTextRange {
                range = markedRange
            } else if !selectedTextRange.isEmpty {
                range = selectedTextRange
            }
        }

        range = extendRangeWithUneditableRanges(range, in: node)

        var hasCmdGroup = false
        if !range.isEmpty {
            hasCmdGroup = true
            cmdManager.beginGroup(with: "Insert replacing")
            cmdManager.deleteText(in: node, for: range)
        }

        cmdManager.inputText(text, in: node, at: cursorPosition)
        if hasCmdGroup {
            cmdManager.endGroup()
        }
        unmarkText()
    }

    public func firstRect(forCharacterRange range: Range<Int>) -> (NSRect, Range<Int>) {
        guard let node = focusedWidget as? TextNode else { return (.zero, 0..<0) }
        let r1 = node.rectAt(sourcePosition: range.lowerBound)
//        let r2 = node.rectAt(sourcePosition: range.upperBound)
        return (r1.offsetBy(dx: node.offsetInDocument.x + 10, dy: node.offsetInDocument.y), range)
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func updateTextAttributesAtCursorPosition() {
        guard let node = focusedWidget as? TextNode else { return }
        let ranges = node.text.rangesAt(position: cursorPosition)
        var caretIsAfterLink = false
        if caretIndex > 0,
           let caret = node.textFrame?.carets[caretIndex - 1],
           !caret.inSource {
            caretIsAfterLink = true
        }

        switch ranges.count {
        case 0:
            state.attributes = []
        case 1:
            guard let range = ranges.first else { return }
            state.attributes = BeamText.removeLinks(from: range.attributes)
        case 2:
            guard let range1 = ranges.first, let range2 = ranges.last else { return }

            if caretIsAfterLink {
                // ignore the left part as we are to the right of a link
                state.attributes = BeamText.removeLinks(from: range2.attributes)
                return
            }
            if !range1.attributes.contains(where: { $0.isLink }) {
                state.attributes = range1.attributes
            } else if !range2.attributes.contains(where: { $0.isLink }) {
                state.attributes = range2.attributes
            } else {
                // They both contain links, let's take the attributes from the left one and remove the link attributes
                state.attributes = BeamText.removeLinks(from: range1.attributes)
            }
        default: fatalError() // NOPE!
        }
    }
}
