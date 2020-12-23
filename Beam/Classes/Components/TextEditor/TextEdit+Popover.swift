//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Foundation
import Cocoa

extension BeamTextEdit {

    internal func showPopover() {
        let currentFrame = self.node.currentFrameInDocument
        popover = Popover<String>(frame: NSRect(x: 210, y: currentFrame.maxY + 20, width: 300, height: 150))

        guard let popover = popover else { return }

        popover.sources = ["Hello", "world"]
        popover.layer?.backgroundColor = NSColor.red.cgColor
        addSubview(popover)
    }

    internal func updatePopover(isDeleteBackward: Bool = false) {
        var text = node.text.text

        if isDeleteBackward && !text.contains(where: { ["@", "#"].contains($0) }) { dismissPopover() }
        guard let range = text.range(of: "@|#", options: .regularExpression) else { return }

        text.removeSubrange(..<range.lowerBound)
        popover?.text = text.replacingOccurrences(of: "@|#", with: "", options: .regularExpression)
    }

    internal func dismissPopover() {
        popover?.removeFromSuperview()
        popover = nil
    }

}
