//
//  BeamTextField.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import SwiftUI
import Combine

struct BeamTextField: NSViewRepresentable {

    typealias NSViewType = NSTextField

    @Binding var text: String
    @Binding var isEditing: Bool

    var placeholder: String
    var font: NSFont?
    var textColor: NSColor?
    var placeholderFont: NSFont?
    var placeholderColor: NSColor?

    var selectedRange: Range<Int>?
    var selectedRangeColor: NSColor?
    var multiline = false
    var secure = false
    var contentType: NSTextContentType?

    var onTextChanged: (String) -> Void = { _ in }
    // Return a replacement text and selection
    var textWillChange: ((_ proposedText: String) -> (String, Range<Int>)?)?

    var onCommit: (_ modifierFlags: NSEvent.ModifierFlags?) -> Void = { _ in }
    var onEscape: (() -> Void)?
    var onBackspace: (() -> Void)?
    /// Returns true to stop event propagation
    var onTab: (() -> Bool)?
    var onCursorMovement: (CursorMovement) -> Bool = { _ in false }
    var onModifierFlagPressed: ((_ modifierFlag: NSEvent) -> Void)?
    var onStartEditing: () -> Void = { }
    var onStopEditing: () -> Void = { }
    var onSelectionChanged: (NSRange) -> Void = { _ in }

    internal var centered: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        var textField: BeamNSTextFieldProtocol = secure ? BeamNSSecureTextField() : BeamNSTextField()
        guard let view = textField as? NSTextField else {
            fatalError("BeamTextField couldn't create a NSTextField")
        }
        let coordinator = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.delegate = coordinator
        view.focusRingType = .none
        view.contentType = contentType

        if !multiline {
            view.usesSingleLineMode = true
        }
        if let textColor = textColor {
            view.textColor = textColor
        }

        if let placeholderColor = placeholderColor {
            textField.placeholderColor = placeholderColor
        }
        if let selectedRangeColor = selectedRangeColor {
            textField.updateTextSelectionColor(selectedRangeColor)
        }
        textField.setText(text, font: font, icon: nil, skipGuards: false)
        textField.setPlaceholder(placeholder, font: placeholderFont ?? font, icon: nil)

        textField.onPerformKeyEquivalent = { [weak coordinator] event in
            coordinator?.performKeyEquivalentHandler(event: event) ?? false
        }
        textField.onFocusChanged = { [weak coordinator] isFocused in
            coordinator?.focusChangedHandler(isFocused: isFocused)
        }
        textField.onSelectionChanged = { [weak coordinator] range in
            coordinator?.selectionChangedHandler(range)
        }
        return view
    }

    func updateNSView(_ view: Self.NSViewType, context: Self.Context) {
        let coordinator = context.coordinator

        guard var textField = view as? BeamNSTextFieldProtocol else { return }
        if view.textColor != textColor {
            view.textColor = textColor
        }

        if let selectedRangeColor = selectedRangeColor {
            textField.updateTextSelectionColor(selectedRangeColor)
        }

        textField.setText(text, font: font, icon: nil, skipGuards: false)
        textField.setPlaceholder(placeholder, font: font, icon: nil)
        textField.shouldUseIntrinsicContentSize = centered

        if selectedRange != coordinator.lastSelectedRange {
            if let range = selectedRange {
                updateSelectedRange(view, range: range, in: text)
            }
            coordinator.lastSelectedRange = selectedRange
        }

        coordinator.firstResponderSetterBlock?.cancel()
        coordinator.windowObservers.removeAll()
        let firstResponderSetterBlock = DispatchWorkItem { [weak coordinator, weak view] in
            guard let view = view, let coordinator = coordinator else { return }
            updateFirstResponderBlock(view: view, coordinator: coordinator)
        }
        coordinator.firstResponderSetterBlock = firstResponderSetterBlock
        DispatchQueue.main.async(execute: firstResponderSetterBlock)
    }

    private func updateFirstResponderBlock(view: Self.NSViewType, coordinator: Coordinator) {
        guard let textField = view as? BeamNSTextFieldProtocol else { return }
        // Force focus on textField
        let isCurrentlyFirstResponder = textField.isFirstResponder
        let wasEditing = coordinator.lastUpdateWasEditing
        if isEditing && !isCurrentlyFirstResponder {
            if let window = view.window {
                window.makeFirstResponder(view)
            } else {
                // Text field didn't have a window yet. Let's wait for the new window to make first responder.
                view.publisher(for: \.window).receive(on: DispatchQueue.main).sink { newWindow in
                    newWindow?.makeFirstResponder(view)
                }.store(in: &coordinator.windowObservers)
            }
        } else if !isEditing && isCurrentlyFirstResponder {
            view.resignFirstResponder()
            // If no other field is a first responder, we can safely clear the window's responder.
            // Otherwise the cursor is not completely removed from the field.
            view.window?.makeFirstResponder(nil)
        } else if !isEditing && wasEditing {
            view.resignFirstResponder()
            view.invalidateIntrinsicContentSize()
        }
        coordinator.lastUpdateWasEditing = isEditing
    }

    private func nsRangeForSelection(from range: Range<Int>, in text: String) -> NSRange {
        let defaultRange = NSRange(location: range.lowerBound, length: range.count)
        guard text.utf16.count != text.count, let utf16Range = text.utf16Range(from: text.range(from: range)) else {
            return defaultRange
        }
        return NSRange(location: utf16Range.startIndex, length: utf16Range.count)
    }

    private func updateSelectedRange(_ view: Self.NSViewType, range: Range<Int>, in text: String) {
        let fieldeditor = view.currentEditor()
        // NSText's selectedRange value is based on UTF-16 characters. We need to convert the range here.
        fieldeditor?.selectedRange = nsRangeForSelection(from: range, in: text)
        if let selectedRangeColor = selectedRangeColor, let textField = view as? BeamNSTextFieldProtocol {
            textField.updateTextSelectionColor(selectedRangeColor)
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        let parent: BeamTextField
        var lastUpdateWasEditing = false
        var lastSelectedRange: Range<Int>?
        var firstResponderSetterBlock: DispatchWorkItem?
        var windowObservers = Set<AnyCancellable>()
        private var automaticScrollSetterBlock: DispatchWorkItem?
        var modifierFlagsPressed: NSEvent.ModifierFlags?

        init(_ textField: BeamTextField) {
            self.parent = textField
        }

        deinit {
            firstResponderSetterBlock?.cancel()
        }

        fileprivate func focusChangedHandler(isFocused: Bool) {
            self.parent.isEditing = isFocused
            if isFocused {
                self.parent.onStartEditing()
            } else {
                self.parent.onStopEditing()
            }
        }

        fileprivate func selectionChangedHandler(_ range: NSRange) {
            self.parent.onSelectionChanged(range)
        }

        fileprivate func performKeyEquivalentHandler(event: NSEvent) -> Bool {
            switch event.keyCode {
            case KeyCode.up.rawValue:
                return parent.onCursorMovement(.up)
            case KeyCode.down.rawValue:
                return parent.onCursorMovement(.down)
            case KeyCode.left.rawValue:
                return parent.onCursorMovement(.left)
            case KeyCode.right.rawValue:
                return parent.onCursorMovement(.right)
            default:
                break
            }

            if let keyCode = KeyCode(rawValue: event.keyCode), keyCode.meansNewLine {
                if event.modifierFlags.contains(.command) {
                    parent.onCommit(.command)
                } else if event.modifierFlags.contains(.shift) {
                    parent.onCommit(.shift)
                } else {
                    parent.onCommit(nil)
                }
                return true
            }

            modifierFlagsPressed = event.modifierFlags
            if !event.modifierFlags.isEmpty {
                parent.onModifierFlagPressed?(event)
            }
            return false
        }

        // MARK: Delegates
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? BeamNSTextFieldProtocol else { return }
            textField.onFocusChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }

            var finalText = textField.stringValue

            if let (newText, newRange) = parent.textWillChange?(finalText),
               let textView = textField.currentEditor() as? BeamTextFieldViewFieldEditor {
                textView.disableAutomaticScrollOnType = true
                // Changing the replacement text here instantaneously, faster than waiting for SwiftUI update
                (textField as? BeamNSTextFieldProtocol)?.setText(newText, font: parent.font, icon: nil, skipGuards: true)
                parent.updateSelectedRange(textField, range: newRange, in: newText)
                finalText = newText

                let block = DispatchWorkItem { [weak textView] in
                    textView?.disableAutomaticScrollOnType = false
                }
                automaticScrollSetterBlock?.cancel()
                automaticScrollSetterBlock = block
                DispatchQueue.main.async(execute: block)
            }
            parent.text = finalText
            parent.onTextChanged(textField.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
                parent.onCommit(modifierFlagsPressed)
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let onEscape = parent.onEscape {
                    onEscape()
                }
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)), let onTab = parent.onTab {
                return onTab()
            } else if commandSelector == #selector(NSResponder.deleteBackward(_:)), let onBackspace = parent.onBackspace {
                onBackspace()
            }
            return false
        }
    }
}

extension BeamTextField {
    func centered(_ centered: Bool) -> some View {
        var copy = self
        copy.centered = centered
        return copy
            .fixedSize(horizontal: centered, vertical: false) // enables the use of intrinsic content size
    }
}
