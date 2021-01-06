//
//  FormatterTypeButton.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 06/01/2021.
//

import Cocoa

class FormatterTypeButton: NSButton {

    public init() {
        super.init(frame: NSRect())
        self.wantsLayer = true
        self.isBordered = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
        }
    }

}
