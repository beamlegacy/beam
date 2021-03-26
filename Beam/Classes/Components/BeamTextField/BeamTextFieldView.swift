//
//  BeamTextFieldView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import Cocoa

protocol BeamTextFieldViewDelegate: class {
    func controlTextDiStartEditing()
}

class BeamTextFieldView: NSTextField {

    weak var textFieldViewDelegate: BeamTextFieldViewDelegate?

    private var _currentText: String?
    private var _currentColor: NSColor?
    private var _placeholderText: String?
    private var _placeholderIcon: NSImage?

    var placeholderColor: NSColor = NSColor.lightGray

    var isFirstResponder: Bool {
        guard let window = window else { return false }
        guard let responder = window.firstResponder else { return false }
        guard responder.isKind(of: NSTextView.self) else { return false }
        guard window.fieldEditor(false, for: nil) != nil else { return false }
        guard let tfResponder = responder as? NSTextView else { return false }
        return self === tfResponder.delegate
    }
    var shouldUseIntrinsicContentSize: Bool = false {
        didSet {
            if oldValue != shouldUseIntrinsicContentSize {
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onFocusChanged: (Bool) -> Void = { _ in }

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

    internal func setText(_ text: String, font: NSFont?, icon: NSImage? = nil) {
        guard text != _currentText || textColor != _currentColor else {
            return
        }
        _currentText = text
        _currentColor = textColor
        let attrs = attributedStringAttributes(textColor ?? NSColor.white, font)
        let textString = NSAttributedString(string: text, attributes: attrs)
        self.attributedStringValue = textString
    }

    internal func setPlaceholder(_ placeholder: String, font: NSFont?, icon: NSImage? = nil) {
        guard placeholder != _placeholderText || icon != _placeholderIcon else {
            return
        }
        _placeholderText = placeholder
        let attrs = attributedStringAttributes(placeholderColor, font)
        var placeholderString = NSAttributedString(string: placeholder, attributes: attrs)

        if let icon = icon {
            let stringWithAttachment = NSMutableAttributedString(withImage: icon, font: font, spacing: 4)
            stringWithAttachment.append(placeholderString)
            placeholderString = stringWithAttachment
        }

        self.placeholderAttributedString = placeholderString
    }

    private func setupTextField() {
        wantsLayer = true
        isBordered = false
        drawsBackground = false
        lineBreakMode = .byTruncatingTail
        allowsEditingTextAttributes = true
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: commandKey(evt:))
    }

    private func commandKey(evt: NSEvent) -> NSEvent {
        if isFirstResponder {
            _ = onPerformKeyEquivalent(evt)
        }
        return evt
    }

    private func attributedStringAttributes(_ foregroundColor: NSColor, _ font: NSFont?) -> [NSAttributedString.Key: Any] {
        let attrs = [
            NSAttributedString.Key.foregroundColor: foregroundColor,
            NSAttributedString.Key.font: font ?? NSFont.systemFont(ofSize: 13)
        ]

        return attrs
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusChanged(true)
        }
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChanged(false)
        }
        return resigned
    }

    override func mouseDown(with event: NSEvent) {
        let convertedLocation = self.convertFromBacking(event.locationInWindow)

        // Find next view below self
        if let viewBelow = self.superview?.subviews.lazy.compactMap({ $0.hitTest(convertedLocation) }).first {
            self.window?.makeFirstResponder(viewBelow)
        }

        super.mouseDown(with: event)
    }

    override var intrinsicContentSize: NSSize {
        guard shouldUseIntrinsicContentSize else {
            return super.intrinsicContentSize
        }
        let width = attributedStringValue.string.count == 0 && self.placeholderAttributedString != nil ? self.placeholderAttributedString!.size().width : self.attributedStringValue.size().width
        return NSSize(width: width + 2, height: self.bounds.height)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isFirstResponder && onPerformKeyEquivalent(event) {
            return true
        }

        return super.performKeyEquivalent(with: event)
    }
}
