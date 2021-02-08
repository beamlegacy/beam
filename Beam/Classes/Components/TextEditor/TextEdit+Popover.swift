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
        guard let node = node as? TextNode else { return }

        popover = BidirectionalPopover()
        updatePopoverPosition(with: node)

        guard let popover = popover,
              let view = window?.contentView else { return }

        view.addSubview(popover)

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            validInternalLink(from: node, title)
            view.window?.makeFirstResponder(self)
        }
    }

    internal func updatePopover(with command: TextRoot.Command = .none) {
        guard let node = node as? TextNode,
              let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition

        if command == .deleteForward && cursorStartPosition >= cursorPosition ||
           command == .moveLeft && cursorPosition <= cursorStartPosition {
            dismissPopoverOrFormatter()
            return
        }

        if command == .moveRight && cursorPosition == node.text.text.count && popoverSuffix != 0 {
            validInternalLink(from: node, String(node.text.text[cursorStartPosition + 1..<cursorPosition - popoverSuffix]))
            return
        }

        let startPosition = popoverPrefix == 0 ? cursorStartPosition : cursorStartPosition + 1
        let linkText = String(node.text.text[startPosition..<cursorPosition])

        node.text.addAttributes([.internalLink(linkText)], to: startPosition - popoverPrefix..<cursorPosition + popoverSuffix)
        let items = linkText.isEmpty ? documentManager.loadAllDocumentsWithLimit(BeamTextEdit.queryLimit) : documentManager.documentsWithLimitTitleMatch(title: linkText, limit: BeamTextEdit.queryLimit)

        popover.items = items.map({ $0.title })
        popover.query = linkText

        updatePopoverPosition(with: node, linkText.isEmpty)
    }

    internal func cancelPopover() {
        guard popover != nil,
              let node = node as? TextNode else { return }

        dismissPopover()
        node.text.removeSubrange((cursorStartPosition + 1 - popoverPrefix)..<(rootNode.cursorPosition + popoverSuffix))
        rootNode.cursorPosition = cursorStartPosition + 1 - popoverPrefix
        showOrHidePersistentFormatter(isPresent: true)
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        popover?.removeFromSuperview()
        popover = nil
    }

    internal func cancelInternalLink() {
        guard let node = node as? TextNode,
              popover != nil else { return }
        let text = node.text.text
        node.text.removeAttributes([.internalLink(text)], from: cursorStartPosition..<rootNode.cursorPosition + text.count)
    }

    private func updatePopoverPosition(with node: TextNode, _ isEmpty: Bool = false) {
        guard let window = window,
              let popover = popover,
              let scrollView = enclosingScrollView else { return }

        let (xOffset, rect) = node.offsetAndFrameAt(index: rootNode.cursorPosition)
        let yOffset = scrollView.documentVisibleRect.origin.y < 0 ? 0 : scrollView.documentVisibleRect.origin.y

        print(node.offsetInDocument)

        var marginTop: CGFloat = 60
        var yPos = node.offsetInDocument.y

        // To avoid the update of X position during the insertion of a new text
        if isEmpty {
            BeamTextEdit.xPos = (xOffset - 20) + node.offsetInDocument.x
        }

        // Popover with Shortcut
        if node.text.text.isEmpty {
            marginTop += 15
            BeamTextEdit.xPos = xOffset + 200
        }

        // yPos -= marginTop
        popover.frame = NSRect(x: BeamTextEdit.xPos, y: yPos, width: popover.idealSize.width, height: popover.idealSize.height)

        // Up position when popover is overlapped or clipped by the superview
        /*if popover.visibleRect.height < popover.idealSize.height {
            popover.frame = NSRect(x: BeamTextEdit.xPos, y: (window.frame.height - node.offsetInDocument.y + yOffset) - 50, width: popover.idealSize.width, height: popover.idealSize.height)
        }*/
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
        initFormatterView(.persistent)
    }

}
