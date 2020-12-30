//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    internal func initPopover() {
        guard let node = node as? TextNode else { return }
        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let x = posX == 0 ? 220 : posX + node.offsetInDocument.x
        let y = rect.maxY == 0 ? rect.maxY + node.offsetInDocument.y + 30 : rect.maxY + node.offsetInDocument.y + 10

        popover = BidirectionalPopover(frame: NSRect(x: x, y: y, width: 300, height: 125))

        guard let popover = popover else { return }

        popover.didSelectTitle = { [unowned self] (title) -> Void in
            node.text.replaceSubrange(cursorStartPosition..<rootNode.cursorPosition, with: title)
            rootNode.cursorPosition = cursorStartPosition + title.count

            node.text.makeInternalLink(cursorStartPosition..<rootNode.cursorPosition)
            dismissPopover()
        }

        addSubview(popover)
    }

    internal func updatePopover(_ command: TextRoot.Command = .none) {
        guard let node = node as? TextNode,
              let data = data,
              let popover = popover else { return }

        var text = node.text.text
        let cursorPosition = rootNode.cursorPosition

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
        popover.items = Array(data.documentManager.documentsWithTitleMatch(title: text).prefix(4))
    }

    internal func dismissPopover() {
        popover?.removeFromSuperview()
        popover = nil
    }

}
