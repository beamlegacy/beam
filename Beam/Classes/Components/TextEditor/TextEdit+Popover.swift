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
    private static var popoverType: PopoverType = .down
    private static let queryLimit = 4

    internal func initPopover() {
        guard let node = node as? TextNode,
              let window = window else { return }

        let height = BidirectionalPopover.viewHeight * CGFloat(BeamTextEdit.queryLimit)

        print("\(height) \(min(node.offsetInDocument.y, window.frame.height)) \(node.frameInDocument)")

        BeamTextEdit.popoverType = height + node.offsetInDocument.y + 75 > window.frame.height ? .up : .down

        updatePosition(with: node)
        popover = BidirectionalPopover(frame: NSRect(x: BeamTextEdit.xPos, y: BeamTextEdit.yPos,
                                                     width: BidirectionalPopover.viewWidth,
                                                     height: BidirectionalPopover.viewHeight))

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

        if command == .moveRight && cursorPosition == node.text.text.count && popoverSuffix != 0 {
            validInternalLink(from: node, String(node.text.text[cursorStartPosition + 1..<cursorPosition - popoverSuffix]))
            return
        }

        let startPosition = popoverPrefix == 0 ? cursorStartPosition : cursorStartPosition + 1
        let linkText = String(node.text.text[startPosition..<cursorPosition])

        node.text.addAttributes([.internalLink(linkText)], to: startPosition - popoverPrefix..<cursorPosition + popoverSuffix)
        let items = linkText.isEmpty ? documentManager.loadAllDocumentsWithLimit() : documentManager.documentsWithLimitTitleMatch(title: linkText, limit: BeamTextEdit.queryLimit)

        popover.items = items.map({ $0.title })
        popover.query = linkText

        updatePosition(with: node)

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

    private func updatePosition(with node: TextNode) {
        guard let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let y = rect.maxY == 0 ? rect.maxY + node.offsetInDocument.y + 25 : rect.maxY + node.offsetInDocument.y + 5

        BeamTextEdit.xPos = posX == 0 ? 208 : posX + node.offsetInDocument.x
        BeamTextEdit.yPos = BeamTextEdit.popoverType == .up ? y - popover.idealSize.height - rect.maxY : y
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

    public override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)

        if popover != nil { cancelPopover() }
    }

}
