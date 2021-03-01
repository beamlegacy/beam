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
        setupUI()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHighlighted {
            contentTintColor = NSColor.formatterIconHoverAndActiveColor
            layer?.backgroundColor = NSColor.formatterButtonBackgroudHoverColor.cgColor
        }
    }

    private func setupUI() {
        self.wantsLayer = true
        self.isBordered = false
    }

}
