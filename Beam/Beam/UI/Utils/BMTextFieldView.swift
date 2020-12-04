//
//  BMTextFieldView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import Cocoa

protocol BMTextFieldViewDelegate: class {
    func controlTextDiStartEditing()
}

class BMTextFieldView: NSTextField {

    weak var textFieldViewDelegate: BMTextFieldViewDelegate?

    public var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onEditingChanged: (Bool) -> Void = { _ in }

    var isEditing = false {
        didSet {
            onEditingChanged(isEditing)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.setupTextFiedl()
    }

    internal func setupTextFiedl() {
        wantsLayer = true
        isBordered = false
        drawsBackground = false

        lineBreakMode = .byTruncatingTail
    }

    override func mouseDown(with event: NSEvent) {
        let convertedLocation = self.convertFromBacking(event.locationInWindow)

        // Find next view below self
        if let viewBelow = self.superview?.subviews.lazy.compactMap({ $0.hitTest(convertedLocation) }).first {
            self.window?.makeFirstResponder(viewBelow)
        }

        super.mouseDown(with: event)

        isEditing = true
        textFieldViewDelegate?.controlTextDiStartEditing()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEditing && onPerformKeyEquivalent(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
