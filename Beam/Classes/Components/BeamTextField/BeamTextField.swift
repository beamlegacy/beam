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
    var selectedRanges: [Range<Int>]?

    var onTextChanged: (String) -> Void = { _ in }
    var onCommit: () -> Void = { }
    var onEscape: () -> Void = { }
    var onCursorMovement: (CursorMovement) -> Bool = { _ in false }
    var onStartEditing: () -> Void = { }
    var onStopEditing: () -> Void = { }
    internal var centered: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let textField = BeamTextFieldView()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.setText(text, font: font)

        if let textColor = textColor {
            textField.textColor = textColor
        }

        if let placeholderColor = placeholderColor {
            textField.placeholderColor = placeholderColor
        }

        textField.onFocusChanged = { isFocused in
            self.isEditing = isFocused
            if isFocused {
                onStartEditing()
            } else {
                onStopEditing()
            }
        }

        textField.onPerformKeyEquivalent = { event in
            switch event.keyCode {
            case KeyCode.up.rawValue:
                return onCursorMovement(.up)
            case KeyCode.down.rawValue:
                return onCursorMovement(.down)
            default:
                return false
            }
        }

        return textField
    }

    func updateNSView(_ textField: Self.NSViewType, context: Self.Context) {
        textField.setText(text, font: font)
        textField.setPlaceholder(placeholder, font: font)
        textField.shouldUseIntrinsicContentSize = centered

        // Force focus on textField
        DispatchQueue.main.async {
            let isCurrentlyFirstResponder = textField.isFirstResponder
            if isEditing && !isCurrentlyFirstResponder {
                textField.becomeFirstResponder()
            } else if !isEditing && isCurrentlyFirstResponder {
                textField.resignFirstResponder()
                // If no other field is a first responder, we can safely clear the window's responder.
                // Otherwise the cursor is not completely removed from the field.
                textField.window?.makeFirstResponder(nil)
            } else if !isEditing {
                textField.invalidateIntrinsicContentSize()
            }
        }

        // Set the range on the textField
        if let range = self.selectedRanges?.first {
            let pos = Int(range.startIndex)
            let len = Int(range.endIndex - range.startIndex)
            updateSelectedRange(textField, range: NSRange(location: pos, length: len))
        }
    }

    func updateSelectedRange(_ textField: Self.NSViewType, range: NSRange) {
        let fieldeditor = textField.currentEditor()
        fieldeditor?.selectedRange = range
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: BeamTextField
        init(_ textField: BeamTextField) {
            self.parent = textField
        }

        // MARK: Protocol
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }
            textField.onFocusChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }

            parent.text = textField.stringValue
            parent.onTextChanged(textField.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
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
