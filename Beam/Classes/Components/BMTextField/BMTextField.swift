//
//  BMTextField.swift
//  Beam
//
//  Created by Ravichandrane Rajendran on 03/12/2020.
//

import SwiftUI

struct BMTextField: NSViewRepresentable {
    typealias NSViewType = BMTextFieldView

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
        let textField = BMTextFieldView()

        textField.delegate = context.coordinator
        textField.textFieldViewDelegate = context.coordinator
        textField.focusRingType = .none

        textField.setText(text, font: font)

        if let textColor = textColor {
            textField.textColor = textColor
        }

        if let placeholderColor = placeholderColor {
            textField.placeholderColor = placeholderColor
        }

        textField.onEditingChanged = { v in
            withAnimation(.default) {
                self.isEditing = v
                if v {
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
                nsView.isEditing = true
                nsView.window?.makeFirstResponder(nsView)
            }
        }

        // Disable editing mode when the textField is out of focus.
        DispatchQueue.main.async {
            if !context.coordinator.parent.isEditing && nsView.isEditing {
                nsView.isEditing = false
                context.coordinator.didBecomeFirstResponder = false
                self.isFirstResponder = false
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

    class Coordinator: NSObject, NSTextFieldDelegate, BMTextFieldViewDelegate {
        let parent: BMTextField
        var didBecomeFirstResponder = false

        init(_ textField: BMTextField) {
            self.parent = textField
        }

        // MARK: Protocol

        func controlTextDiStartEditing() {
            self.parent.isEditing = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            self.parent.isEditing = false
            self.parent.isFirstResponder = false
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSViewType else { return }

            self.parent.text = textField.stringValue
            self.parent.onTextChanged(textField.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                self.parent.onCommit()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                self.parent.onEscape()
                return true
            }

            return false
        }

    }
}
