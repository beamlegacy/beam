//
//  BeamTextFieldView.swift
//  Beam
//
// swiftlint:disable file_length

import Cocoa

final class BeamTextFieldViewFieldEditor: NSTextView {
    var disableAutomaticScrollOnType: Bool = false
    var caretWidth: CGFloat?

    override func preferredPasteboardType(from availableTypes: [NSPasteboard.PasteboardType], restrictedToTypesFrom allowedTypes: [NSPasteboard.PasteboardType]?) -> NSPasteboard.PasteboardType? {
        if availableTypes.contains(.string) {
            return .string
        }
        return super.preferredPasteboardType(from: availableTypes, restrictedToTypesFrom: allowedTypes)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        guard let caretWidth = caretWidth else { return super.drawInsertionPoint(in: rect, color: color, turnedOn: flag) }
        var newRect = rect
        newRect.size.width = caretWidth
        super.drawInsertionPoint(in: newRect, color: color, turnedOn: flag)
    }

    override func setNeedsDisplay(_ rect: NSRect, avoidAdditionalLayout flag: Bool) {
        guard let caretWidth = caretWidth else { return super.setNeedsDisplay(rect, avoidAdditionalLayout: flag) }
        var newRect = rect
        newRect.size.width += caretWidth - 1
        super.setNeedsDisplay(newRect, avoidAdditionalLayout: flag)
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
    var ignoreResponderChanges: Bool { get }
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
    func updateCaretColor(_ color: NSColor?)
    func updateCaretWidth(_ width: CGFloat?)

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
    private var _caretColor: NSColor?
    private var flagsMonitor: Any?
    fileprivate var ignoreResponderChanges = false

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
        textField?.allowsEditingTextAttributes = true
        textField?.lineBreakMode = .byTruncatingTail
        textField?.cell?.truncatesLastVisibleLine = true
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
        // changing placeholderAttributedString resigns first responder from NSCell._restartEditingWithTextView(_ :)
        let wasFirstResponder = isFirstResponder
        if wasFirstResponder {
            ignoreResponderChanges = true
        }
        textField?.placeholderString = placeholder
        textField?.placeholderAttributedString = placeholderString
        if wasFirstResponder {
            ignoreResponderChanges = false
        }
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

    func updateCaretColor(_ color: NSColor? = nil) {
        guard let textView = textField?.currentEditor() as? NSTextView, let newColor = color else { return }
        if _caretColor != newColor {
            _caretColor = newColor
            textView.insertionPointColor = newColor
        }
    }

    func updateCaretWidth(_ width: CGFloat?) {
        guard let textView = textField?.currentEditor() as? BeamTextFieldViewFieldEditor else { return }
        guard textView.caretWidth != width else { return }
        textView.caretWidth = width
    }

    // MARK: Out of BeamNSTextFieldProtocol

    private func attributedStringAttributes(_ foregroundColor: NSColor, _ font: NSFont?) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.allowsDefaultTighteningForTruncation = false
        let attrs = [
            NSAttributedString.Key.foregroundColor: foregroundColor,
            NSAttributedString.Key.font: font ?? NSFont.systemFont(ofSize: 13),
            NSAttributedString.Key.paragraphStyle: style
        ]
        return attrs
    }

    var intrinsicContentSize: CGSize {
        guard let textField = textField else { return .zero }
        let width = textField.attributedStringValue.string.count == 0 && textField.placeholderAttributedString != nil ? textField.placeholderAttributedString!.size().width : textField.attributedStringValue.size().width
        return NSSize(width: width + 2, height: textField.bounds.height)
    }

    func handleBecomeFirstResponder(became: Bool) {
        if became && !ignoreResponderChanges {
            parent?.onFocusChanged(true)
        }
        updateTextSelectionColor(_selectionRangeColor)
        updateCaretColor(_caretColor)
    }

    func handleResignFirstResponder(resigned: Bool) {
        if resigned && !ignoreResponderChanges {
            parent?.onFocusChanged(false)
        }
    }

    func handleSelectionChange() {
        if let range = selectedRange {
            parent?.onSelectionChanged(range)
        }
        updateTextSelectionColor(_selectionRangeColor)
    }
}

/// Custom NSTextFieldCell subclass overriding a single method to provide our custom field editor.
private final class BeamNSTextFieldCell: NSTextFieldCell {
    let editor = BeamTextFieldViewFieldEditor()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        return editor
    }
}

class BeamNSTextField: NSTextField, BeamNSTextFieldProtocol {

    private var sharedImpl = BeamNSTextFieldProtocolSharedImpl(textField: nil)

    override class var cellClass: AnyClass? {
        get {
            return BeamNSTextFieldCell.self
        }
        set { _ = newValue }
    }

    var isFirstResponder: Bool {
        sharedImpl.isFirstResponder
    }
    var ignoreResponderChanges: Bool {
        sharedImpl.ignoreResponderChanges
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

    func updateCaretColor(_ color: NSColor?) {
        sharedImpl.updateCaretColor(color)
    }

    func updateCaretWidth(_ width: CGFloat?) {
        sharedImpl.updateCaretWidth(width)
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        sharedImpl.ignoreResponderChanges = true
        let became = super.becomeFirstResponder()
        sharedImpl.ignoreResponderChanges = false
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

// MARK: - Secure support

class BeamNSSecureTextField: NSSecureTextField, BeamNSTextFieldProtocol {

    private var sharedImpl = BeamNSTextFieldProtocolSharedImpl(textField: nil)

    var isFirstResponder: Bool {
        sharedImpl.isFirstResponder
    }
    var ignoreResponderChanges: Bool {
        sharedImpl.ignoreResponderChanges
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

    func updateCaretColor(_ color: NSColor?) {
        sharedImpl.updateCaretColor(color)
    }

    func updateCaretWidth(_ width: CGFloat?) {
        // unfortunately unsupported for secure fields currently, crashing with a custom cell...
        sharedImpl.updateCaretWidth(width)
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
