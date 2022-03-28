//
//  TextEditOperations.swift
//  Beam
//
//  Created by Sebastien Metrot on 26/10/2020.
//

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
    var cmdContext: Widget? {
        editor?.focusedWidget ?? editor?.rootNode
    }

    func increaseNodeIndentation(_ node: ElementNode) -> Bool {
        guard !node.readOnly,
              node.element.canIncreaseIndentation,
              !(node.parent?.isTreeBoundary ?? false),
              let newParent = node.previousSibbling() as? ElementNode
        else { return false }
        return focusedCmdManager.reparentElement(node, to: newParent, atIndex: newParent.element.children.count)
    }

    func decreaseNodeIndentation(_ node: ElementNode) -> Bool {
        guard !node.readOnly,
              !(node.parent?.isTreeBoundary ?? false),
              !(node.parent?.parent?.isTreeBoundary ?? false),
              let prevParent = node.displayedElement.parent,
              let newParent = prevParent.parent,
              let parentIndexInParent = newParent.id == node.displayedElementId ? node.displayedElement.children.count : prevParent.indexInParent
        else { return false }

        return focusedCmdManager.reparentElement(node.displayedElement, to: newParent, atIndex: parentIndexInParent + 1)
    }

    func increaseNodeSelectionIndentation() {
        guard let selection = root?.state.nodeSelection else { return }

        focusedCmdManager.beginGroup(with: "IncreaseIndentationGroup")
        for node in selection.sortedRoots {
            _ = increaseNodeIndentation(node)
        }
        focusedCmdManager.endGroup()
    }

    func decreaseNodeSelectionIndentation() {
        guard let selection = root?.state.nodeSelection else { return }

        focusedCmdManager.beginGroup(with: "DecreaseIndentationGroup")
        for node in selection.sortedRoots.reversed() {
            _ = decreaseNodeIndentation(node)
        }
        focusedCmdManager.endGroup()
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

        let cmdManager = focusedCmdManager
        cmdManager.beginGroup(with: "Delete selected nodes")
        defer { cmdManager.endGroup() }

        if let prevWidget = sortedNodes.first?.previousVisibleNode(ElementNode.self) {
            cmdManager.focusElement(prevWidget, cursorPosition: prevWidget.textCount)
        } else if let nextVisibleNode = sortedNodes.last?.nextVisibleNode(ElementNode.self) {
            if (nextVisibleNode as? ProxyTextNode) == nil {
                cmdManager.focusElement(nextVisibleNode, cursorPosition: 0)
            }
        }

        for node in sortedNodes.reversed() {
            guard node.element as? BeamNote == nil else { continue }

            // reparent children to previous sibbling or existing parent
            let unproxied = node.unproxyElement
            if node.open, let oldIndexInParent = unproxied.indexInParent,
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
            if !(editor?.journalMode ?? false) {
                editor?.scroll(.zero)
            }
            return newElement
        }
        return nil
    }

    func replaceSelection(with str: String) {
        guard let node = focusedWidget as? TextNode, !node.readOnly, !selectedTextRange.isEmpty
        else { return }

        let bText = BeamText(text: str, attributes: root?.state.attributes ?? [])
        focusedCmdManager.beginGroup(with: "Erase selection")
        defer { focusedCmdManager.endGroup() }
        focusedCmdManager.replaceText(in: node, for: selectedTextRange, with: bText)
        focusedCmdManager.cancelSelection(node)
        focusedCmdManager.focusElement(node, cursorPosition: selectedTextRange.lowerBound + bText.count)
    }

    // swiftlint:disable:next function_body_length
    public func deleteForward() {
        guard state.nodeSelection == nil else {
            editor?.hideInlineFormatter()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? ElementNode,
              let parentElement = node.displayedElement.parent,
              let nodeParent = node.parent
        else { return }

        focusedCmdManager.beginGroup(with: "Delete forward")
        defer {
            focusedCmdManager.endGroup()
        }

        if let textNode = node as? TextNode {
            if cursorPosition == textNode.textCount && state.selectedTextRange.isEmpty {
                guard let nextNode = node.nextVisibleNode(ElementNode.self) else {
                    return
                }

                // Simple case: the next node contains text:
                if let nextTextNode = nextNode as? TextNode {
                    let pos = textNode.textCount
                    focusedCmdManager.insertText(nextTextNode.elementText, in: textNode, at: pos)
                    moveChildrenOf(nextTextNode, to: textNode)
                    focusedCmdManager.deleteElement(for: nextTextNode)
                    return
                }

                // Complex case: the next node contains an embed or an image
                focusedCmdManager.focusElement(nextNode, cursorPosition: 0)
                deleteForward()
                return
            } else {
                // Standard text deletion
                focusedCmdManager.deleteText(in: textNode, for: rangeToDeleteText(in: textNode, cursorAt: cursorPosition, forward: true))
            }
        } else {
            // we are not in a text node
            if cursorPosition == node.textCount {
                // We must delete whatever is following us, unless it's not an element node
                guard let nextNode = node.nextVisibleNode(ElementNode.self) else { return }

                // If it's a text node then we must remove the first character from the text node and leave the cursor there
                if let nextTextNode = nextNode as? TextNode {
                    focusedCmdManager.focusElement(nextTextNode, cursorPosition: 0)
                    deleteForward()
                    return
                } else {
                    // If the next node is not a text node then we must remove the node altogether and leave the cursor where it is
                    focusedCmdManager.focusElement(nextNode, cursorPosition: 0)
                    deleteForward()
                    focusedCmdManager.focusElement(node, cursorPosition: node.textCount)
                }
            } else {
                // we are at the start of the element node, we can just delete it and move all its children to the previous node
                guard let nextNode = node.nextVisibleNode(ElementNode.self) else {
                    let newNextElement = BeamElement()
                    focusedCmdManager.insertElement(newNextElement, inElement: parentElement, afterElement: node.displayedElement)
                    let newNode = nodeFor(newNextElement, withParent: nodeParent)
                    focusedCmdManager.focusElement(newNode, cursorPosition: 0)
                    focusedCmdManager.deleteElement(for: node)
                    return
                }
                moveChildrenOf(node.displayedElement, to: parentElement, atOffset: node.displayedElement.indexInParent)
                focusedCmdManager.focusElement(nextNode, cursorPosition: 0)
                focusedCmdManager.deleteElement(for: node)
            }
        }
    }

    func moveChildrenOf(_ node: ElementNode, to newParent: ElementNode, atOffset: Int? = nil) {
        let offset = atOffset ?? newParent.children.count
        for (i, child) in node.displayedElement.children.enumerated() {
            focusedCmdManager.reparentElement(child, to: newParent.displayedElement, atIndex: offset + i)
        }
    }

    func moveChildrenOf(_ element: BeamElement, to newParent: BeamElement, atOffset: Int? = nil) {
        let offset = atOffset ?? newParent.children.count
        for (i, child) in element.children.enumerated() {
            focusedCmdManager.reparentElement(child, to: newParent, atIndex: offset + i)
        }
    }

    //swiftlint:disable:next cyclomatic_complexity function_body_length
    public func deleteBackward() {
        guard root?.state.nodeSelection == nil else {
            editor?.hideInlineFormatter()
            eraseNodeSelection(createEmptyNodeInPlace: false)
            return
        }

        guard let node = focusedWidget as? ElementNode,
              let parentElement = node.displayedElement.parent,
              let nodeParent = node.parent
        else { return }

        let cmdManager = focusedCmdManager
        cmdManager.beginGroup(with: "Delete backward")
        defer {
            cmdManager.endGroup()
        }

        // We can't remove the root of a link & ref proxy node:
        if let ref = node as? ProxyTextNode,
           (ref.parent is BreadCrumb) || (ref.parent is BlockReferenceNode),
           cursorPosition == 0 {
            if !state.selectedTextRange.isEmpty {
                cmdManager.deleteText(in: ref, for: rangeToDeleteText(in: ref, cursorAt: cursorPosition, forward: false))
            }
            return
        }

        if let textNode = node as? TextNode, !textNode.readOnly {
            if cursorPosition == 0 && state.selectedTextRange.isEmpty {
                if node.previousNodeIsRoot && node.textCount == 0 {
                    switch node.elementKind {
                    case .heading:
                        node.cmdManager.formatText(in: textNode, for: .bullet, with: nil, for: nil, isActive: false)
                        return
                    default:
                        return
                    }
                }

                guard let prevNode = node.previousVisibleNode(ElementNode.self),
                      !(node is BlockReferenceNode) else {
                    return
                }

                // Simple case: the previous node contains text:
                if let prevTextNode = prevNode as? TextNode {
                    let pos = prevTextNode.textCount
                    cmdManager.insertText(textNode.elementText, in: prevTextNode, at: pos)
                    if prevTextNode.displayedElement.children.isEmpty {
                        prevTextNode.open = textNode.open
                    }
                    moveChildrenOf(textNode, to: prevTextNode)
                    cmdManager.focusElement(prevTextNode, cursorPosition: pos)
                    cmdManager.deleteElement(for: textNode)
                    return
                }

                if node.textCount == 0 {
                    // we are in an empty text node: delete it
                    moveChildrenOf(node, to: prevNode, atOffset: node.displayedElement.indexInParent)
                    cmdManager.focusElement(prevNode, cursorPosition: prevNode.textCount)
                    cmdManager.deleteElement(for: textNode)
                    return
                }

                // Complex case: the previous node contains an embed or an image
                cmdManager.focusElement(prevNode, cursorPosition: prevNode.textCount)
                deleteBackward()
            } else {
                // Standard text deletion
                cmdManager.deleteText(in: textNode, for: rangeToDeleteText(in: textNode, cursorAt: cursorPosition, forward: false))
            }
        } else {
            // we are not in an editable text node
            if cursorPosition == 0 && node.textCount > 0 {
                // We must delete whatever is behind us, unless it's not an element node
                guard let prevNode = node.previousVisibleNode(ElementNode.self) else { return }

                // If prev node's a text node then we must remove the last character from the text node and leave the cursor there
                if let prevTextNode = prevNode as? TextNode, prevTextNode.textCount > 0 {
                    cmdManager.focusElement(prevTextNode, cursorPosition: prevTextNode.textCount)
                    deleteBackward()
                } else {
                    // If the previous node is not a text node with text
                    // then we must remove the node altogether and leave the cursor where it is
                    if prevNode.parent as? TextRoot != nil {
                        moveChildrenOf(prevNode, to: self, atOffset: prevNode.displayedElement.indexInParent)
                        cmdManager.deleteElement(for: prevNode)
                        cmdManager.focusElement(node, cursorPosition: 0)
                    } else {
                        cmdManager.focusElement(prevNode, cursorPosition: prevNode.textCount)
                        deleteBackward()
                        cmdManager.focusElement(node, cursorPosition: 0)
                    }
                }
            } else {
                // we are at the end of the element node, we can just delete it and move all its children to the previous node
                // but if the node is the first node then we must replace it with an empty text node
                let prevNode = node.previousVisibleNode(ElementNode.self) ?? {
                    let newPrevElement = BeamElement()
                    cmdManager.insertElement(newPrevElement, inElement: parentElement, afterElement: node.displayedElement)
                    return nodeFor(newPrevElement, withParent: nodeParent)
                }()
                if prevNode.displayedElement.children.isEmpty {
                    prevNode.open = node.open
                }
                moveChildrenOf(node, to: prevNode)
                cmdManager.deleteElement(for: node.element)
                cmdManager.focusElement(prevNode, cursorPosition: prevNode.textCount)
            }
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
                focusedCmdManager.deleteText(in: node, for: selectedTextRange)
            }

            let bText = BeamText(text: "\n", attributes: [])
            focusedCmdManager.inputText(bText, in: node, at: cursorPosition)
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
        node.invalidateTextAsync()
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
            focusedCmdManager.beginGroup(with: "Insert replacing")
            focusedCmdManager.deleteText(in: node, for: range)
        }

        let bText = BeamText(text: string, attributes: root?.state.attributes ?? [])
        focusedCmdManager.inputText(bText, in: node, at: cursorPosition)
        if hasCmdGroup {
            focusedCmdManager.endGroup()
        }
        cancelSelection(.start)
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
            focusedCmdManager.beginGroup(with: "Insert replacing")
            focusedCmdManager.deleteText(in: node, for: range)
        }

        focusedCmdManager.inputText(text, in: node, at: cursorPosition)
        if hasCmdGroup {
            focusedCmdManager.endGroup()
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

        var finalAttributes: [BeamText.Attribute] = []
        switch ranges.count {
        case 0:
            finalAttributes = []
        case 1:
            guard let range = ranges.first else { return }
            finalAttributes = BeamText.removeLinks(from: range.attributes)
        case 2:
            guard let range1 = ranges.first, let range2 = ranges.last else { return }

            if caretIsAfterLink {
                // ignore the left part as we are to the right of a link
                finalAttributes = BeamText.removeLinks(from: range2.attributes)
                return
            } else {
                if !range1.attributes.contains(where: { $0.isLink }) {
                    finalAttributes = range1.attributes
                } else if !range2.attributes.contains(where: { $0.isLink }) {
                    finalAttributes = range2.attributes
                } else {
                    // They both contain links, let's take the attributes from the left one and remove the link attributes
                    finalAttributes = BeamText.removeLinks(from: range1.attributes)
                }
            }
        default: fatalError() // NOPE!
        }

        state.attributes = BeamText.removeAnyDecoration(from: finalAttributes)
    }
}
