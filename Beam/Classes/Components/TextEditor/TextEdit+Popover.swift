//
//  TextEdit+Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Foundation
import Cocoa

extension BeamTextEdit {

    func showPopover() {
        let currentFrame = self.node.currentFrameInDocument
        popover = Popover(frame: NSRect(x: 210, y: currentFrame.maxY + 20, width: 300, height: 150))

        guard let popover = popover else { return }

        popover.layer?.backgroundColor = NSColor.red.cgColor
        addSubview(popover)
    }

    func updatePopover(isDeleteBackward: Bool = false) {
        var text = node.text.text
        if isDeleteBackward && !text.contains("@") { dismissPopover() }

        if let dotRange = text.range(of: "@") {
            text.removeSubrange(..<dotRange.lowerBound)
        }

        popover?.text = text.replacingOccurrences(of: "@", with: "")
    }

    func dismissPopover() {
        guard let popover = popover else { return }
        popover.removeFromSuperview()
    }

}
