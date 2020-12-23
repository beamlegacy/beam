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
        print(currentFrame)
        popover = Popover(frame: NSRect(x: 210, y: currentFrame.maxY + 20, width: 300, height: 150))

        guard let popover = popover else { return }

        popover.layer?.backgroundColor = NSColor.red.cgColor
        addSubview(popover)
    }

    func updatePopover() {
        if node.text.text.isEmpty { dismissPopover() }
        popover?.text = node.text.text.replacingOccurrences(of: "@", with: "")
    }

    func dismissPopover() {
        guard let popover = popover else { return }
        popover.removeFromSuperview()
    }

}
