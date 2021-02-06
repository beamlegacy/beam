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

    var isEditing = false {
        didSet {
            onEditingChanged(isEditing)
        }
    }

    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onFocusChanged: (Bool) -> Void = { _ in }
    var onEditingChanged: (Bool) -> Void = { _ in }

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

    internal func setText(_ text: String, font: NSFont?) {
        let attrs = buildAttributedString(textColor ?? NSColor.white, font)
        let textString = NSAttributedString(string: text, attributes: attrs)

        self.attributedStringValue = textString
    }

    internal func setPlacholder(_ placeholder: String, font: NSFont?) {
        let attrs = buildAttributedString(placeholderColor, font)
        let placeholderString = NSAttributedString(string: placeholder, attributes: attrs)

        self.placeholderAttributedString = placeholderString
    }

    private func setupTextField() {
        wantsLayer = true
        isBordered = false
        drawsBackground = false
        lineBreakMode = .byTruncatingTail
    }

    private func buildAttributedString(_ foregroundColor: NSColor, _ font: NSFont?) -> [NSAttributedString.Key: Any] {
        let attrs = [
            NSAttributedString.Key.foregroundColor: foregroundColor,
            NSAttributedString.Key.font: font ?? NSFont.systemFont(ofSize: 13)
        ]

        return attrs
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        onFocusChanged(true)
        return super.becomeFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        let convertedLocation = self.convertFromBacking(event.locationInWindow)

        // Find next view below self
        if let viewBelow = self.superview?.subviews.lazy.compactMap({ $0.hitTest(convertedLocation) }).first {
            self.window?.makeFirstResponder(viewBelow)
        }

        isEditing = true
        super.mouseDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isEditing && onPerformKeyEquivalent(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
