//
//  FocusableTextField.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 27/07/2021.
//

import SwiftUI
import Foundation

struct FocusableTextField: NSViewRepresentable {

    var placeholder: String
    @Binding var text: String

    var secured: Bool = false

    var autoFocus = false
    var tag: Int = -1
    var focusTag: Binding<Int>?
    var onChange: (() -> Void)?
    var onCommit: (() -> Void)?
    var onTabKeystroke: (() -> Void)?
    var onReturnKeystroke: (() -> Void)?

    @State private var didFocus = false

    func makeNSView(context: Context) -> NSTextField {
        let textField = secured ? NSSecureTextField() : NSTextField()
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.bezelStyle = .roundedBezel
        textField.tag = tag
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if autoFocus && !didFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.mainWindow?.makeFirstResponder(nsView)
                didFocus = true
            }
        }

        if let focusTag = focusTag {
            if focusTag.wrappedValue == nsView.tag {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.mainWindow?.makeFirstResponder(nsView)
                    self.focusTag?.wrappedValue = -1
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(with: self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField

        init(with parent: FocusableTextField) {
            self.parent = parent
            super.init()

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleAppDidBecomeActive(notification:)),
                                                   name: NSApplication.didBecomeActiveNotification,
                                                   object: nil)
        }

        @objc
        func handleAppDidBecomeActive(notification: Notification) {
            if parent.autoFocus && !parent.didFocus {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5)) {
                    self.parent.didFocus = false
                }
            }
        }

        // MARK: - NSTextFieldDelegate Methods
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
            parent.onChange?()
        }

        func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
            parent.text = fieldEditor.string
            parent.onCommit?()
            return true
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSStandardKeyBindingResponding.insertTab(_:)) {
                parent.onTabKeystroke?()
                return true
            } else if commandSelector == #selector(NSStandardKeyBindingResponding.insertNewline(_:)) {
                NSApp.mainWindow?.makeFirstResponder(nil)
                parent.onReturnKeystroke?()
                return true
            }
            return false
        }
    }
}
struct FocusableTextField_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FocusableTextField(placeholder: "Placeholder", text: .constant("A text"), secured: true)
            FocusableTextField(placeholder: "Placeholder", text: .constant("A text"))
            FocusableTextField(placeholder: "Placeholder", text: .constant(""))
        }
    }
}
