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
    private static let viewHeight: CGFloat = 36
    private static var posX: CGFloat = 0
    private static var posY: CGFloat = 0

    internal func initPopover() {
        guard let node = node as? TextNode else { return }
        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let x = posX == 0 ? 220 : posX + node.offsetInDocument.x
        let y = rect.maxY == 0 ? rect.maxY + node.offsetInDocument.y + 30 : rect.maxY + node.offsetInDocument.y + 10

        BeamTextEdit.posX = x
        BeamTextEdit.posY = y
        popover = BidirectionalPopover(frame: NSRect(x: x, y: y, width: BeamTextEdit.viewWidth, height: BeamTextEdit.viewHeight))

        guard let popover = popover else { return }

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            node.text.replaceSubrange(cursorStartPosition..<rootNode.cursorPosition, with: title)
            rootNode.cursorPosition = cursorStartPosition + title.count

            node.text.makeInternalLink(cursorStartPosition..<rootNode.cursorPosition)
            dismissPopover()
        }

        addSubview(popover)
    }

    internal func updatePopover(with command: TextRoot.Command = .none) {
        guard let node = node as? TextNode,
              let data = data,
              let popover = popover else { return }

        let cursorPosition = rootNode.cursorPosition
        var text = node.text.text

        if command == .deleteForward && cursorStartPosition == cursorPosition ||
           command == .moveLeft && cursorPosition - 1 <= cursorStartPosition {
            dismissPopover()
            return
        }

        let startIndex = text.index(at: cursorStartPosition)
        let endIndex = text.index(at: cursorPosition)
        let endDistance = text.distance(from: text.endIndex, to: endIndex)
        let prefix = String(text[startIndex])

        if endDistance < 0 {
            text.removeSubrange(endIndex...)
            text.removeSubrange(..<startIndex)
        } else {
            text.removeSubrange(..<startIndex)
        }

        text = text.replacingOccurrences(of: prefix, with: "")
        let items = data.documentManager.documentsWithTitleMatch(title: text).prefix(7).map({ $0.title })
        var height = items.isEmpty ? BeamTextEdit.viewHeight : (BeamTextEdit.viewHeight * CGFloat(items.count)) + 36

        if items.count == 1 || items.isEmpty { height = BeamTextEdit.viewHeight * 2 }

        popover.frame = NSRect(x: BeamTextEdit.posX, y: BeamTextEdit.posY, width: BeamTextEdit.viewWidth, height: height)
        popover.items = items
        popover.query = text
    }

    internal func dismissPopover() {
        popover?.removeFromSuperview()
        popover = nil
    }

}
