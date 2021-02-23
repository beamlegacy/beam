//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let queryLimit = 4
    private static var xPos: CGFloat = 0

    internal func initPopover() {
        guard let node = focussedWidget as? TextNode else { return }

        popover = BidirectionalPopover()

        guard let popover = popover,
              let view = window?.contentView else { return }

        view.addSubview(popover)

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            self.validInternalLink(from: node, title)
            view.window?.makeFirstResponder(self)
        }
    }

    internal func updatePopover(with command: TextRoot.Command = .none) {
        guard let node = focussedWidget as? TextNode,
              let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition

        if command == .deleteForward && cursorStartPosition >= cursorPosition ||
           command == .moveLeft && cursorPosition <= cursorStartPosition {
            dismissPopoverOrFormatter()
            return
        }

        if command == .moveRight &&
            cursorPosition == node.text.text.count &&
            popoverSuffix != 0 {

            if node.text.text == "[[]]" {
                cursorStartPosition = 0
                cancelInternalLink()
                return
            }

            validInternalLink(from: node, String(node.text.text[cursorStartPosition + 1..<cursorPosition - popoverSuffix]))

            return
        }

        let startPosition = popoverPrefix == 0 ? cursorStartPosition : cursorStartPosition + 1
        let linkText = String(node.text.text[startPosition..<cursorPosition])
        if linkText.hasPrefix(" ") {
            // escape if the user type a space right after the start of the popover
            cancelPopover(leaveTextAsIs: true)
            return
        }

        node.text.addAttributes([.internalLink(linkText)], to: startPosition - popoverPrefix..<cursorPosition + popoverSuffix)
        let items = linkText.isEmpty ? documentManager.loadAllDocumentsWithLimit(BeamTextEdit.queryLimit) : documentManager.documentsWithLimitTitleMatch(title: linkText, limit: BeamTextEdit.queryLimit)

        popover.items = items.map({ $0.title })
        popover.query = linkText

        updatePopoverPosition(with: node, linkText.isEmpty)
    }

    internal func cancelPopover(leaveTextAsIs: Bool = false) {
        guard popover != nil,
              let node = focussedWidget as? TextNode else { return }

        dismissPopover()
        let range = (cursorStartPosition + 1 - popoverPrefix)..<(rootNode.cursorPosition + popoverSuffix)
        if leaveTextAsIs {
            node.text.removeAttributes([.internalLink("")], from: range)
        } else {
            node.text.removeSubrange(range)
            rootNode.cursorPosition = range.lowerBound
        }
        showOrHidePersistentFormatter(isPresent: true)
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        popover?.removeFromSuperview()
        popover = nil
    }

    internal func cancelInternalLink() {
        guard let node = focussedWidget as? TextNode,
              popover != nil else { return }
        let text = node.text.text
        node.text.removeAttributes([.internalLink(text)], from: cursorStartPosition..<rootNode.cursorPosition + text.count)
    }

    private func updatePopoverPosition(with node: TextNode, _ isEmpty: Bool = false) {
        guard let popover = popover,
              let scrollView = enclosingScrollView else { return }

        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let offsetGlobal = convert(node.offsetInDocument, to: nil)
        let yOffset = scrollView.documentVisibleRect.origin.y < 0 ? 0 : scrollView.documentVisibleRect.origin.y
        let marginTop: CGFloat = rect.maxY == 0 ? 30 : 10

        var yPos = offsetGlobal.y - rect.maxY - popover.idealSize.height

        // To avoid the update of X position during the insertion of a new text
        if isEmpty {
            BeamTextEdit.xPos = xOffset == 0 ? offsetGlobal.x + 15 : (xOffset + offsetGlobal.x) - 10
        }

        // Popover with Shortcut
        if node.text.text.isEmpty {
            BeamTextEdit.xPos = xOffset + 200
        }

        yPos -= marginTop
        popover.frame = NSRect(x: BeamTextEdit.xPos, y: yPos, width: popover.idealSize.width, height: popover.idealSize.height)

        // Up position when popover is overlapped or clipped by the superview
        if popover.visibleRect.height < popover.idealSize.height {
            popover.frame = NSRect(
                x: BeamTextEdit.xPos,
                y: offsetGlobal.y + yOffset + marginTop,
                width: popover.idealSize.width,
                height: popover.idealSize.height
            )
        }
    }

    private func validInternalLink(from node: TextNode, _ title: String) {
        let startPosition = popoverPrefix == 0 ? cursorStartPosition : cursorStartPosition + 1
        let replacementStart = startPosition - popoverPrefix
        let replacementEnd = rootNode.cursorPosition + popoverSuffix
        let linkEnd = replacementStart + title.count

        node.text.replaceSubrange(replacementStart..<replacementEnd, with: title)
        node.text.makeInternalLink(replacementStart..<linkEnd)
        rootNode.cursorPosition = linkEnd
        dismissPopover()
        showOrHidePersistentFormatter(isPresent: true)
    }

}
