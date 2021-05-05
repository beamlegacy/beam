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
        textField.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        textField.delegate = context.coordinator
        textField.focusRingType = .none

        if let textColor = textColor {
            textField.textColor = textColor
        }

        if let placeholderColor = placeholderColor {
            textField.placeholderColor = placeholderColor
        }

        textField.setText(text, font: font)
        textField.onPerformKeyEquivalent = self.performKeyEquivalentHandler
        textField.onFocusChanged = { isFocused in
            self.focusChangedHandler(isFocused: isFocused, context: context)
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

        DispatchQueue.main.async {
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

            // Set the selected range on the textField
            if self.selectedRange != coordinator.lastSelectedRange {
                if let range = self.selectedRange {
                    let pos = Int(range.startIndex)
                    let len = Int(range.endIndex - range.startIndex)
                    self.updateSelectedRange(textField, range: NSRange(location: pos, length: len))
                }
                context.coordinator.lastSelectedRange = self.selectedRange
            }
        }
    }

    private func updateSelectedRange(_ textField: Self.NSViewType, range: NSRange) {
        let fieldeditor = textField.currentEditor()
        fieldeditor?.selectedRange = range
    }

    private func focusChangedHandler(isFocused: Bool, context: Self.Context) {
        if !self.isEditing && isFocused {
            // text field could focus for 2 reasons: [user clicked | us programmatically].
            // When user clicks, our callbacks will make the view re-render,
            // causing the selection to be messy. We prevent this here.
            // See Cursor Blip in https://linear.app/beamapp/issue/BE-661
            context.coordinator.nextUpdateShouldClearSelection = true
        }
        self.isEditing = isFocused
        if isFocused {
            onStartEditing()
        } else {
            onStopEditing()
        }
    }

    private func performKeyEquivalentHandler(event: NSEvent) -> Bool {
        switch event.keyCode {
        case KeyCode.up.rawValue:
            return onCursorMovement(.up)
        case KeyCode.down.rawValue:
            return onCursorMovement(.down)
        case KeyCode.left.rawValue:
            return onCursorMovement(.left)
        case KeyCode.right.rawValue:
            return onCursorMovement(.right)
        case KeyCode.enter.rawValue where event.modifierFlags.contains(.command):
            onCommit(.command)
            return true
        default:
            break
        }
        if !event.modifierFlags.isEmpty {
            onModifierFlagPressed?(event)
        }
        return false
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

        init(_ textField: BeamTextField) {
            self.parent = textField
        }

        // MARK: Delegates
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }
            textField.onFocusChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }

            var finalText = textField.stringValue

            if let (newText, newRange) = parent.textWillChange?(finalText) {
                // Changing the replacement text here instantaneously, faster than waiting for SwiftUI update
                textField.setText(newText, font: parent.font, skipGuards: true)
                parent.updateSelectedRange(textField, range: NSRange(location: newRange.lowerBound, length: newRange.count))
                finalText = newText
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
