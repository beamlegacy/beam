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
    var multiline = false

    var onTextChanged: (String) -> Void = { _ in }
    // Return a replacement text and selection
    var textWillChange: ((_ proposedText: String) -> (String, Range<Int>)?)?

    var onCommit: (_ modifierFlags: NSEvent.ModifierFlags?) -> Void = { _ in }
    var onEscape: () -> Void = { }
    var onTab: (() -> Void)?
    var onCursorMovement: (CursorMovement) -> Bool = { _ in false }
    var onModifierFlagPressed: ((_ modifierFlag: NSEvent) -> Void)?
    var onStartEditing: () -> Void = { }
    var onStopEditing: () -> Void = { }

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

        textField.setText(text, font: font)
        textField.onPerformKeyEquivalent = { [weak coordinator] event in
            coordinator?.performKeyEquivalentHandler(event: event) ?? false
        }
        textField.onFocusChanged = { [weak coordinator] isFocused in
            coordinator?.focusChangedHandler(isFocused: isFocused)
        }
        return textField
    }

    func updateNSView(_ textField: Self.NSViewType, context: Self.Context) {
        if textField.textColor != textColor {
            textField.textColor = textColor
        }
        textField.setText(text, font: font)
        textField.setPlaceholder(placeholder, font: font)
        textField.shouldUseIntrinsicContentSize = centered

        clearSelectionIfNeeded(textField, context: context)

        if selectedRange != context.coordinator.lastSelectedRange {
            if let range = selectedRange {
                let pos = Int(range.startIndex)
                let len = Int(range.endIndex - range.startIndex)
                updateSelectedRange(textField, range: NSRange(location: pos, length: len))
            }
            context.coordinator.lastSelectedRange = selectedRange
        }

        context.coordinator.firstResponderSetterBlock?.cancel()
        let firstResponderSetterBlock = DispatchWorkItem {
            let coordinator = context.coordinator
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
        context.coordinator.firstResponderSetterBlock = firstResponderSetterBlock
        DispatchQueue.main.async(execute: firstResponderSetterBlock)
    }

    private func updateSelectedRange(_ textField: Self.NSViewType, range: NSRange) {
        let fieldeditor = textField.currentEditor()
        fieldeditor?.selectedRange = range
    }

    private func clearSelectionIfNeeded(_ textField: Self.NSViewType, context: Self.Context) {
        if context.coordinator.nextUpdateShouldClearSelection &&
            textField.isFirstResponder &&
            selectedRange?.isEmpty != false {
            textField.placeCursorAtCurrentMouseLocation()
        }
        context.coordinator.nextUpdateShouldClearSelection = false
    }

    class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        let parent: BeamTextField
        var nextUpdateShouldClearSelection = false
        var lastUpdateWasEditing = false
        var lastSelectedRange: Range<Int>?
        var firstResponderSetterBlock: DispatchWorkItem?
        private var automaticScrollSetterBlock: DispatchWorkItem?

        init(_ textField: BeamTextField) {
            self.parent = textField
        }

        fileprivate func focusChangedHandler(isFocused: Bool) {
            if !self.parent.isEditing && isFocused {
                // text field could focus for 2 reasons: [user clicked | us programmatically].
                // When user clicks, our callbacks will make the view re-render,
                // causing the selection to be messy. We prevent this here.
                // See Cursor Blip in https://linear.app/beamapp/issue/BE-661
                self.nextUpdateShouldClearSelection = true
            }
            self.parent.isEditing = isFocused
            if isFocused {
                self.parent.onStartEditing()
            } else {
                self.parent.onStopEditing()
            }
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
            case KeyCode.enter.rawValue where event.modifierFlags.contains(.command):
                parent.onCommit(.command)
                return true
            default:
                break
            }
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
                parent.onCommit(nil)
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            } else if let onTab = parent.onTab, commandSelector == #selector(NSResponder.insertTab(_:)) {
                onTab()
                return true
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
