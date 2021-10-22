//
//  BeamTextField.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import SwiftUI

struct BeamTextField: NSViewRepresentable {

    typealias NSViewType = BeamTextFieldView

    @Binding var text: String
    @Binding var isEditing: Bool

    var placeholder: String
    var font: NSFont?
    var textColor: NSColor?
    var placeholderColor: NSColor?

    var selectedRange: Range<Int>?
    var selectedRangeColor: NSColor?
    var multiline = false

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
        let textField = BeamTextFieldView()
        let coordinator = context.coordinator
        textField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        textField.delegate = coordinator
        textField.focusRingType = .none

        if !multiline {
            textField.usesSingleLineMode = true
        }

        if let textColor = textColor {
            textField.textColor = textColor
        }

        if let placeholderColor = placeholderColor {
            textField.placeholderColor = placeholderColor
        }

        if let selectedRangeColor = selectedRangeColor {
            textField.updateTextSelectionColor(selectedRangeColor)
        }

        textField.setText(text, font: font)
        textField.onPerformKeyEquivalent = { [weak coordinator] event in
            coordinator?.performKeyEquivalentHandler(event: event) ?? false
        }
        textField.onFocusChanged = { [weak coordinator] isFocused in
            coordinator?.focusChangedHandler(isFocused: isFocused)
        }
        textField.onSelectionChanged = { [weak coordinator] range in
            coordinator?.selectionChangedHandler(range)
        }
        return textField
    }

    func updateNSView(_ textField: Self.NSViewType, context: Self.Context) {
        let coordinator = context.coordinator

        if textField.textColor != textColor {
            textField.textColor = textColor
        }

        if let selectedRangeColor = selectedRangeColor {
            textField.updateTextSelectionColor(selectedRangeColor)
        }

        textField.setText(text, font: font)
        textField.setPlaceholder(placeholder, font: font)
        textField.shouldUseIntrinsicContentSize = centered

        if selectedRange != coordinator.lastSelectedRange {
            if let range = selectedRange {
                let pos = Int(range.startIndex)
                let len = Int(range.endIndex - range.startIndex)
                updateSelectedRange(textField, range: NSRange(location: pos, length: len))
            }
            coordinator.lastSelectedRange = selectedRange
        }

        coordinator.firstResponderSetterBlock?.cancel()
        let firstResponderSetterBlock = DispatchWorkItem { [unowned coordinator] in
            // Force focus on textField
            let isCurrentlyFirstResponder = textField.isFirstResponder
            let wasEditing = coordinator.lastUpdateWasEditing
            if isEditing && !isCurrentlyFirstResponder {
                textField.becomeFirstResponder()
            } else if !isEditing && isCurrentlyFirstResponder {
                textField.resignFirstResponder()
                // If no other field is a first responder, we can safely clear the window's responder.
                // Otherwise the cursor is not completely removed from the field.
                textField.window?.makeFirstResponder(nil)
            } else if !isEditing && wasEditing {
                textField.resignFirstResponder()
                textField.invalidateIntrinsicContentSize()
            }
            coordinator.lastUpdateWasEditing = isEditing
        }
        coordinator.firstResponderSetterBlock = firstResponderSetterBlock
        DispatchQueue.main.async(execute: firstResponderSetterBlock)
    }

    private func updateSelectedRange(_ textField: Self.NSViewType, range: NSRange) {
        let fieldeditor = textField.currentEditor()
        fieldeditor?.selectedRange = range
        if let selectedRangeColor = selectedRangeColor {
            textField.updateTextSelectionColor(selectedRangeColor)
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        let parent: BeamTextField
        var lastUpdateWasEditing = false
        var lastSelectedRange: Range<Int>?
        var firstResponderSetterBlock: DispatchWorkItem?
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
            guard let textField = obj.object as? NSViewType else { return }
            textField.onFocusChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }

            var finalText = textField.stringValue

            if let (newText, newRange) = parent.textWillChange?(finalText),
               let textView = textField.currentEditor() as? BeamTextFieldViewFieldEditor {
                textView.disableAutomaticScrollOnType = true
                // Changing the replacement text here instantaneously, faster than waiting for SwiftUI update
                textField.setText(newText, font: parent.font, skipGuards: true)
                parent.updateSelectedRange(textField, range: NSRange(location: newRange.lowerBound, length: newRange.count))
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
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
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
        return
            copy
                .fixedSize(horizontal: centered, vertical: false) // enables the use of intrinsic content size
    }
}
