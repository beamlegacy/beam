//
//  Popover.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 22/12/2020.
//

import Cocoa

class Popover: NSView {

    // MARK: - Initializer
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func doCommand(_ command: TextRoot.Command) {}

}
