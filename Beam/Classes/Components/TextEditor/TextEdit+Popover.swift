//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static var xPos: CGFloat = 0
    private static var yPos: CGFloat = 0

    internal func initPopover() {
        guard let node = node as? TextNode else { return }

        updatePosition(with: node)
        popover = BidirectionalPopover(frame: NSRect(x: BeamTextEdit.xPos, y: BeamTextEdit.yPos,
                                                     width: BidirectionalPopover.viewWidth,
                                                     height: BidirectionalPopover.viewHeight))

        guard let popover = popover,
              let view = window?.contentView else { return }

        view.addSubview(popover)

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            validInternalLink(from: node, title)
        }
    }

    internal func updatePopover(with command: TextRoot.Command = .none) {
        guard let node = node as? TextNode,
              let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition

        if command == .deleteForward && cursorStartPosition == cursorPosition ||
           command == .moveLeft && cursorPosition <= cursorStartPosition {
            dismissAndShowPersistentView()
            return
        }

        if command == .moveRight && cursorPosition == node.text.text.count && popoverSuffix != 0 {
            validInternalLink(from: node, String(node.text.text[cursorStartPosition + 1..<cursorPosition - popoverSuffix]))
            return
        }

        let startPosition = popoverPrefix == 0 ? cursorStartPosition : cursorStartPosition + 1
        let linkText = String(node.text.text[startPosition..<cursorPosition])

        node.text.addAttributes([.internalLink(linkText)], to: startPosition - popoverPrefix..<cursorPosition + popoverSuffix)
        let items = linkText.isEmpty ? documentManager.loadAllDocumentsWithLimit() : documentManager.documentsWithLimitTitleMatch(title: linkText)

        popover.items = items.map({ $0.title })
        popover.query = linkText

        updatePosition(with: node, linkText.isEmpty)

        popover.frame = NSRect(x: BeamTextEdit.xPos, y: BeamTextEdit.yPos, width: popover.idealSize.width, height: popover.idealSize.height)
    }

    internal func cancelPopover() {
        guard popover != nil,
              let node = node as? TextNode else { return }

        dismissPopover()
        node.text.removeSubrange((cursorStartPosition + 1 - popoverPrefix)..<(rootNode.cursorPosition + popoverSuffix))
        rootNode.cursorPosition = cursorStartPosition + 1 - popoverPrefix
        initFormatterView()
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        cancelInternalLink()
        popover?.removeFromSuperview()
        popover = nil
    }

    internal func dismissAndShowPersistentView() {
        cancelInternalLink()
        dismissPopover()
        initFormatterView()
    }

    internal func cancelInternalLink() {
        guard let node = node as? TextNode,
              popover != nil else { return }
        let text = node.text.text
        node.text.removeAttributes([.internalLink(text)], from: cursorStartPosition..<rootNode.cursorPosition + text.count)
    }

    private func updatePosition(with node: TextNode, _ isEmpty: Bool = false) {
        guard let window = window,
              let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let marginTop: CGFloat = ignoreFirstDrag ? 80 : 65

        // to avoid update X position during new text is inserted
        if isEmpty {
            BeamTextEdit.xPos = (posX - 20) + node.offsetInDocument.x
        }

        BeamTextEdit.yPos = (window.frame.height - (rect.maxY + node.offsetInDocument.y) - popover.idealSize.height) - marginTop
    }

    private func validInternalLink(from node: TextNode, _ title: String) {
        let replacementStart = cursorStartPosition + 1 - popoverPrefix
        let replacementEnd = rootNode.cursorPosition + popoverSuffix
        let linkEnd = replacementStart + title.count
        node.text.replaceSubrange(replacementStart..<replacementEnd, with: title)
        node.text.makeInternalLink(replacementStart..<linkEnd)
        rootNode.cursorPosition = linkEnd
        dismissPopover()
        initFormatterView()
    }

}
