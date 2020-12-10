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

    var placeholderText: String?
    var placeholderColor: NSColor = NSColor.lightGray
    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onEditingChanged: (Bool) -> Void = { _ in }

    var isEditing = false {
        didSet {
            onEditingChanged(isEditing)
        }
    }

    public init() {
        super.init(frame: NSRect())
        setupTextField()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        setupTextField()
        super.draw(dirtyRect)
    }

    internal func setupTextField() {
        wantsLayer = true
        isBordered = false
        drawsBackground = false

        guard let placeholder = placeholderText else { return }

        let attrs = [
            NSAttributedString.Key.foregroundColor: placeholderColor,
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: font?.pointSize ?? 13)
        ]

        let placeholderString = NSAttributedString(string: placeholder, attributes: attrs)
        self.placeholderAttributedString = placeholderString
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
