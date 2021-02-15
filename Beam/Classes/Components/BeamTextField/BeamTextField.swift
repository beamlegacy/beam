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
    @Binding var isFirstResponder: Bool

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

        textField.onFocusChanged = { isFocus in
            self.isEditing = isFocus
            self.isFirstResponder = isFocus
            context.coordinator.didBecomeFirstResponder = isFocus
        }

        textField.onEditingChanged = { isEditing in
            withAnimation(.default) {
                self.isEditing = isEditing
                if isEditing {
                    onStartEditing()
                } else {
                    onStopEditing()
                }
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

    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
        nsView.setText(text, font: font)
        nsView.setPlacholder(placeholder, font: font)

        // Enable focus on textField
        if isFirstResponder && !context.coordinator.didBecomeFirstResponder {
            context.coordinator.didBecomeFirstResponder = true

            DispatchQueue.main.async {
                nsView.becomeFirstResponder()
            }
        }

        // Set the range on the textField
        if let range = self.selectedRanges?.first {
            let fieldeditor = nsView.currentEditor()
            let pos = Int(range.startIndex)
            let len = Int(range.endIndex - range.startIndex)
            fieldeditor?.selectedRange = NSRange(location: pos, length: len)
        }
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: BeamTextField
        var didBecomeFirstResponder = false

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
