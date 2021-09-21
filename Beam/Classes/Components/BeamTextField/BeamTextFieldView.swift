//
//  BeamTextFieldView.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import Cocoa

class BeamTextFieldViewFieldEditor: NSTextView {
    var disableAutomaticScrollOnType: Bool = false

    override func preferredPasteboardType(from availableTypes: [NSPasteboard.PasteboardType], restrictedToTypesFrom allowedTypes: [NSPasteboard.PasteboardType]?) -> NSPasteboard.PasteboardType? {
        if availableTypes.contains(.string) {
            return .string
        }
        return super.preferredPasteboardType(from: availableTypes, restrictedToTypesFrom: allowedTypes)
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        guard disableAutomaticScrollOnType == false else { return }
        super.scrollRangeToVisible(range)
    }
}

class BeamTextFieldView: NSTextField {

    private var _currentText: String?
    private var _currentColor: NSColor?
    private var _selectionRangeColor: NSColor = BeamColor.Generic.textSelection.nsColor
    private var _placeholderText: String?
    private var _placeholderIcon: NSImage?

    var placeholderColor: NSColor = NSColor.lightGray

    var isFirstResponder: Bool {
        guard let window = window else { return false }
        guard let responder = window.firstResponder else { return false }
        guard window.fieldEditor(false, for: self) != nil else { return false }
        guard let tfResponder = (responder as? BeamTextFieldViewFieldEditor) ?? (responder as? NSTextView) else { return false }
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
    var onSelectionChanged: (NSRange) -> Void = { _ in }

    var monitor: Any?

    public init() {
        super.init(frame: NSRect())
        setupTextField()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        guard let monitor = monitor else { return }
        NSEvent.removeMonitor(monitor)
    }
    override func draw(_ dirtyRect: NSRect) {
        setupTextField()
        super.draw(dirtyRect)

    }

    internal func setText(_ text: String, font: NSFont?, icon: NSImage? = nil, skipGuards: Bool = false) {
        guard skipGuards || text != _currentText || textColor != _currentColor else {
            return
        }
        _currentText = text
        _currentColor = textColor
        let attrs = attributedStringAttributes(textColor ?? NSColor.white, font)
        let textString = NSAttributedString(string: text, attributes: attrs)
        if text.isEmpty && self.font?.pointSize != font?.pointSize {
            // When the string is empty, attributed string don't apply font correctly,
            // Resulting in the cursor being a different size.
            self.font = font
        }
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
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: commandKey(evt:))
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

    func updateTextSelectionColor(_ color: NSColor? = nil) {
        if let newColor = color,
           _selectionRangeColor != newColor {
            _selectionRangeColor = newColor
        }
        if let textView = currentEditor() as? NSTextView {
            textView.selectedTextAttributes = [
                .backgroundColor: _selectionRangeColor
            ]
        }
    }

    var selectedRange: NSRange? {
        guard let textView = currentEditor() as? NSTextView else {
            return nil
        }

        return textView.selectedRange()
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusChanged(true)
        }
        updateTextSelectionColor()
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

    private var mouseLocation: CGPoint?
    func placeCursorAtCurrentMouseLocation() {
        if let location = mouseLocation, let tv = self.currentEditor() as? NSTextView {
            let index = tv.characterIndexForInsertion(at: location)
            self.currentEditor()?.selectedRange = NSRange(location: index, length: 0)
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseLocation = self.convert(event.locationInWindow, from: nil)
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

extension BeamTextFieldView: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        if let range = selectedRange {
            onSelectionChanged(range)
        }
        updateTextSelectionColor()
    }
}

extension BeamTextFieldView: CustomWindowFieldEditorProvider {
    static let customFieldEditor: NSText = {
        BeamTextFieldViewFieldEditor()
    }()

    func fieldEditor(_ createFlag: Bool) -> NSText? {
        return Self.customFieldEditor
    }
}
