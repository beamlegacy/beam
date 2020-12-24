//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

extension BeamTextEdit {

    internal func initPopover() {
        let currentFrame = self.node.currentFrameInDocument
        let cursorPosition = rootNode.cursorPosition
        print(cursorPosition, rootNode.text)
        popover = Popover<String>(frame: NSRect(x: 210, y: currentFrame.maxY + 30, width: 300, height: 150))

        guard let popover = popover else { return }

        popover.sources = ["Hello", "world"]
        popover.layer?.backgroundColor = NSColor.red.cgColor
        addSubview(popover)
    }

    internal func updatePopover(_ command: TextRoot.Command = .none) {
        var text = node.text.text
        let regex = "@|#"

        if command == .deleteForward && !text.contains(where: { ["@", "#"].contains($0) }) { dismissPopover() }

        guard let range = text.range(of: regex, options: .regularExpression) else { return }
        let prefixIndex = text.distance(from: text.startIndex, to: range.lowerBound)
        let cursorPosition = rootNode.cursorPosition - 1

        if command == .moveLeft && cursorPosition <= prefixIndex { dismissPopover() }

        text.removeSubrange(..<range.lowerBound)
        popover?.text = text.replacingOccurrences(of: regex, with: "", options: .regularExpression)
    }

    internal func dismissPopover() {
        guard popover != nil else { return }
        popover?.removeFromSuperview()
        popover = nil
    }

}
