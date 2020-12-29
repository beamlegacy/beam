//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    internal func initPopover() {
        let cursorPosition = rootNode.cursorPosition
        let (posX, rect) = node.offsetAndFrameAt(index: cursorPosition)
        let x = posX == 0 ? 220 : posX + 200
        let y = rect.maxY == 0 ? 60 : rect.maxY + 40

        popover = BidirectionalPopover(frame: NSRect(x: x, y: y, width: 300, height: 125))

        guard let popover = popover else { return }
        popover.delegate = self

        addSubview(popover)
    }

    internal func updatePopover(_ command: TextRoot.Command = .none) {
        guard let data = data, let popover = popover else { return }

        var text = node.text.text
        let regex = "@|#"

        if command == .deleteForward && !text.contains(where: { ["@", "#"].contains($0) }) { dismissPopover() }

        guard let range = text.range(of: regex, options: .regularExpression) else { return }
        let prefixIndex = text.distance(from: text.startIndex, to: range.lowerBound)
        let cursorPosition = rootNode.cursorPosition - 1

        if command == .moveLeft && cursorPosition <= prefixIndex { dismissPopover() }

        text.removeSubrange(..<range.lowerBound)
        text = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)

        popover.items = Array(data.documentManager.documentsWithTitleMatch(title: text).prefix(4))
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        popover?.removeFromSuperview()
        popover = nil
    }

}

extension BeamTextEdit: BidirectionalDelegate {

    func didSelectItems(_ title: String) {
        print(title)
    }

}
