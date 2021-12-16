//
//  BeamTextFieldView.swift
//  Beam
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

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        guard let pasteboardItem = pasteboard.pasteboardItems?.first,
              let text = pasteboardItem.string(forType: .string) else {
            super.paste(sender)
            return
        }
        let cleanText = text.components(separatedBy: .newlines).joined(separator: " ")
        insertText(cleanText, replacementRange: selectedRange())
    }
}

protocol BeamNSTextFieldProtocol {

    var isFirstResponder: Bool { get }
    var shouldUseIntrinsicContentSize: Bool { get set }
    var selectedRange: NSRange? { get }
    var placeholderColor: NSColor { get set }

    var onPerformKeyEquivalent: (NSEvent) -> Bool { get set }
    var onFocusChanged: (Bool) -> Void { get set }
    var onSelectionChanged: (NSRange) -> Void { get set }

    func setupTextField()
    func setText(_ text: String, font: NSFont?, icon: NSImage?, skipGuards: Bool)
    func setPlaceholder(_ placeholder: String, font: NSFont?, icon: NSImage?)
    func updateTextSelectionColor(_ color: NSColor?)

}

private class BeamNSTextFieldProtocolSharedImpl: BeamNSTextFieldProtocol {
    weak var textField: NSTextField?
    private var parent: BeamNSTextFieldProtocol? {
        textField as? BeamNSTextFieldProtocol
    }

    private var _currentText: String?
    private var _currentColor: NSColor?
    private var _placeholderText: String?
    private var _placeholderIcon: NSImage?

    private var _selectionRangeColor: NSColor = BeamColor.Generic.textSelection.nsColor
    private var flagsMonitor: Any?

    var isFirstResponder: Bool {
        guard let textField = textField, let window = textField.window else { return false }
        guard let responder = window.firstResponder else { return false }
        guard window.fieldEditor(false, for: textField) != nil else { return false }
        guard let tfResponder = (responder as? BeamTextFieldViewFieldEditor) ?? (responder as? NSTextView) else { return false }
        return textField === tfResponder.delegate
    }
    var shouldUseIntrinsicContentSize: Bool = false {
        didSet {
            if oldValue != shouldUseIntrinsicContentSize {
                textField?.invalidateIntrinsicContentSize()
            }
        }
    }
    var selectedRange: NSRange? {
        guard let textView = textField?.currentEditor() as? NSTextView else {
            return nil
        }
        return textView.selectedRange()
    }
    var placeholderColor: NSColor = NSColor.lightGray

    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in fatalError("onPerformKeyEquivalent not implemented by shared implementation") }
    var onFocusChanged: (Bool) -> Void = { _ in fatalError("onFocusChanged not implemented by shared implementation") }
    var onSelectionChanged: (NSRange) -> Void = { _ in fatalError("onSelectionChanged not implemented by shared implementation") }

    init(textField: NSTextField?) {
        self.textField = textField
    }

    deinit {
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func setupTextField() {
        textField?.wantsLayer = true
        textField?.isBordered = false
        textField?.drawsBackground = false
        textField?.lineBreakMode = .byTruncatingTail
        textField?.allowsEditingTextAttributes = true
        if flagsMonitor == nil {
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: commandKey(evt:))
        }
    }

    private func commandKey(evt: NSEvent) -> NSEvent {
        if isFirstResponder {
            _ = parent?.onPerformKeyEquivalent(evt)
        }
        return evt
    }

    func setText(_ text: String, font: NSFont?, icon: NSImage? = nil, skipGuards: Bool = false) {
        guard skipGuards || text != _currentText || textField?.textColor != _currentColor else {
            return
        }
        _currentText = text
        _currentColor = textField?.textColor
        let attrs = attributedStringAttributes(textField?.textColor ?? NSColor.white, font)
        let textString = NSAttributedString(string: text, attributes: attrs)
        if text.isEmpty && textField?.font?.pointSize != font?.pointSize {
            // When the string is empty, attributed string don't apply font correctly,
            // Resulting in the cursor being a different size.
            textField?.font = font
        }
        textField?.attributedStringValue = textString
    }

    func setPlaceholder(_ placeholder: String, font: NSFont?, icon: NSImage? = nil) {
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
        textField?.placeholderAttributedString = placeholderString
    }

    func updateTextSelectionColor(_ color: NSColor? = nil) {
        if let newColor = color,
           _selectionRangeColor != newColor {
            _selectionRangeColor = newColor
        }
        if let textView = textField?.currentEditor() as? NSTextView {
            textView.selectedTextAttributes = [
                .backgroundColor: _selectionRangeColor
            ]
        }
    }

    // MARK: Out of BeamNSTextFieldProtocol

    private func attributedStringAttributes(_ foregroundColor: NSColor, _ font: NSFont?) -> [NSAttributedString.Key: Any] {
        let attrs = [
            NSAttributedString.Key.foregroundColor: foregroundColor,
            NSAttributedString.Key.font: font ?? NSFont.systemFont(ofSize: 13)
        ]

        return attrs
    }

    var intrinsicContentSize: CGSize {
        guard let textField = textField else { return .zero }
        let width = textField.attributedStringValue.string.count == 0 && textField.placeholderAttributedString != nil ? textField.placeholderAttributedString!.size().width : textField.attributedStringValue.size().width
        return NSSize(width: width + 2, height: textField.bounds.height)
    }

    func handleBecomeFirstResponder(became: Bool) {
        if became {
            parent?.onFocusChanged(true)
        }
        updateTextSelectionColor()
    }

    func handleResignFirstResponder(resigned: Bool) {
        if resigned {
            parent?.onFocusChanged(false)
        }
    }

    func handleSelectionChange() {
        if let range = selectedRange {
            parent?.onSelectionChanged(range)
        }
        updateTextSelectionColor()
    }
}

class BeamNSTextField: NSTextField, BeamNSTextFieldProtocol {

    private var sharedImpl = BeamNSTextFieldProtocolSharedImpl(textField: nil)

    var isFirstResponder: Bool {
        sharedImpl.isFirstResponder
    }
    var shouldUseIntrinsicContentSize: Bool {
        get { sharedImpl.shouldUseIntrinsicContentSize }
        set { sharedImpl.shouldUseIntrinsicContentSize = newValue }
    }
    var selectedRange: NSRange? {
        sharedImpl.selectedRange
    }
    var placeholderColor: NSColor {
        get { sharedImpl.placeholderColor }
        set { sharedImpl.placeholderColor = newValue }
    }
    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onFocusChanged: (Bool) -> Void = { _ in }
    var onSelectionChanged: (NSRange) -> Void = { _ in }

    public init() {
        super.init(frame: NSRect())
        sharedImpl = .init(textField: self)
        setupTextField()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        setupTextField()
        super.draw(dirtyRect)
    }

    func setText(_ text: String, font: NSFont?, icon: NSImage? = nil, skipGuards: Bool = false) {
        sharedImpl.setText(text, font: font, icon: icon, skipGuards: skipGuards)
    }

    func setPlaceholder(_ placeholder: String, font: NSFont?, icon: NSImage? = nil) {
        sharedImpl.setPlaceholder(placeholder, font: font, icon: icon)
    }

    func setupTextField() {
        sharedImpl.setupTextField()
    }

    func updateTextSelectionColor(_ color: NSColor? = nil) {
        sharedImpl.updateTextSelectionColor(color)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        sharedImpl.handleBecomeFirstResponder(became: became)
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        sharedImpl.handleResignFirstResponder(resigned: resigned)
        return resigned
    }

    override var intrinsicContentSize: NSSize {
        let superSize = super.intrinsicContentSize
        guard shouldUseIntrinsicContentSize else {
            return superSize
        }
        return CGSize(width: sharedImpl.intrinsicContentSize.width, height: superSize.height)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isFirstResponder && onPerformKeyEquivalent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

extension BeamNSTextField: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        sharedImpl.handleSelectionChange()
    }
}

extension BeamNSTextField: CustomWindowFieldEditorProvider {
    static let customFieldEditor: NSText = {
        BeamTextFieldViewFieldEditor()
    }()

    func fieldEditor(_ createFlag: Bool) -> NSText? {
        return Self.customFieldEditor
    }
}

// MARK: - Secure support

class BeamNSSecureTextField: NSSecureTextField, BeamNSTextFieldProtocol {

    private var sharedImpl = BeamNSTextFieldProtocolSharedImpl(textField: nil)

    var isFirstResponder: Bool {
        sharedImpl.isFirstResponder
    }
    var shouldUseIntrinsicContentSize: Bool {
        get { sharedImpl.shouldUseIntrinsicContentSize }
        set { sharedImpl.shouldUseIntrinsicContentSize = newValue }
    }
    var selectedRange: NSRange? {
        sharedImpl.selectedRange
    }
    var placeholderColor: NSColor {
        get { sharedImpl.placeholderColor }
        set { sharedImpl.placeholderColor = newValue }
    }
    var onPerformKeyEquivalent: (NSEvent) -> Bool = { _ in return false }
    var onFocusChanged: (Bool) -> Void = { _ in }
    var onSelectionChanged: (NSRange) -> Void = { _ in }

    public init() {
        super.init(frame: NSRect())
        sharedImpl = .init(textField: self)
        setupTextField()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        setupTextField()
        super.draw(dirtyRect)
    }

    func setText(_ text: String, font: NSFont?, icon: NSImage? = nil, skipGuards: Bool = false) {
        sharedImpl.setText(text, font: font, icon: icon, skipGuards: skipGuards)
    }

    func setPlaceholder(_ placeholder: String, font: NSFont?, icon: NSImage? = nil) {
        sharedImpl.setPlaceholder(placeholder, font: font, icon: icon)
    }

    func setupTextField() {
        sharedImpl.setupTextField()
    }

    func updateTextSelectionColor(_ color: NSColor? = nil) {
        sharedImpl.updateTextSelectionColor(color)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        sharedImpl.handleBecomeFirstResponder(became: became)
        return became
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        sharedImpl.handleResignFirstResponder(resigned: resigned)
        return resigned
    }

    override var intrinsicContentSize: NSSize {
        let superSize = super.intrinsicContentSize
        guard shouldUseIntrinsicContentSize else {
            return superSize
        }
        return CGSize(width: sharedImpl.intrinsicContentSize.width, height: superSize.height)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isFirstResponder && onPerformKeyEquivalent(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

extension BeamNSSecureTextField: NSTextViewDelegate {
    func textViewDidChangeSelection(_ notification: Notification) {
        sharedImpl.handleSelectionChange()
    }
}
