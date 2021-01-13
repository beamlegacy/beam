//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    // MARK: - Properties
    private static let viewWidth: CGFloat = 248
    private static let viewHeight: CGFloat = 36.5
    private static var posX: CGFloat = 0
    private static var posY: CGFloat = 0

    internal func initPopover() {
        guard let node = node as? TextNode else { return }
        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let x = posX == 0 ? 208 : posX + node.offsetInDocument.x
        let y = rect.maxY == 0 ? rect.maxY + node.offsetInDocument.y + 25 : rect.maxY + node.offsetInDocument.y + 5

        BeamTextEdit.posX = x
        BeamTextEdit.posY = y
        popover = BidirectionalPopover(frame: NSRect(x: x, y: y, width: BeamTextEdit.viewWidth, height: BeamTextEdit.viewHeight))

        guard let popover = popover else { return }

        addSubview(popover)

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

        let linkText = String(node.text.text[cursorStartPosition + 1..<cursorPosition])

        if command == .moveRight && cursorPosition == node.text.text.count && popoverSuffix != 0 {
            validInternalLink(from: node, String(node.text.text[cursorStartPosition + 1..<cursorPosition - popoverSuffix]))
            return
        }

        node.text.addAttributes([.internalLink(linkText)], to: cursorStartPosition + 1 - popoverPrefix..<cursorPosition + popoverSuffix)
        let items = linkText.isEmpty ? documentManager.loadAllDocumentsWithLimit() : documentManager.documentsWithLimitTitleMatch(title: linkText)
        var height = BeamTextEdit.viewHeight * CGFloat(items.count) + (linkText.isEmpty ? 0 : 36.5)

        if items.count == 1 || items.isEmpty { height = BeamTextEdit.viewHeight * 2 }

        popover.frame = NSRect(x: BeamTextEdit.posX, y: BeamTextEdit.posY, width: BeamTextEdit.viewWidth, height: height)
        popover.items = items.map({ $0.title })
        popover.query = linkText
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
        popover?.removeFromSuperview()
        popover = nil
    }

    internal func dismissAndShowPersistentView() {
        dismissPopover()
        cancelInternalLink()
        initFormatterView()
    }

    internal func cancelInternalLink() {
        guard let node = node as? TextNode else { return }
        let text = node.text.text
        node.text.removeAttributes([.internalLink(text)], from: cursorStartPosition..<rootNode.cursorPosition + text.count)
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
