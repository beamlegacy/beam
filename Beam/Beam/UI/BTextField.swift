//
//  BTextField.swift
//  Beam
//
//  Created by Sebastien Metrot on 20/09/2020.
//

import Foundation
import SwiftUI
import Combine

enum CursorMovement {
    case up
    case down
    case left
    case right
}

struct BTextField: NSViewRepresentable {
    typealias NSViewType = BNSTextField
    private var textField: BNSTextField
    private var onEditingChanged: (Bool) -> Void
    private var onCommit: () -> Void
    private var onCursorMovement: (CursorMovement) -> Bool
    private var formatter: Formatter = Formatter()
    var text: Binding<String>
    private var cancellables = [Cancellable]()


    //    Creates a text field with a text label generated from a title string.
    //    Available when Label is Text.
    init<S>(_ title: S, text: Binding<String>,
            onEditingChanged: @escaping (Bool) -> Void = { _ in },
            onCommit: @escaping () -> Void = {},
            onCursorMovement: @escaping (CursorMovement) -> Bool = { _ in return false },
            focusOnCreation: Bool = false
    ) where S : StringProtocol
    {
        self.text = text
        self.textField  = BNSTextField(string: self.text, focusOnCreation: focusOnCreation)
        self.textField.placeholderString = title as? String
        self.textField.textColor = NSColor(named: "TextColor")
//        self.textField.backgroundColor = NSColor(named: "SearchBarBackgroundColor")
        self.textField.focusRingType = .none
        self.textField.isBordered = false
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.onCursorMovement = onCursorMovement

        configure()
    }

    //    Creates a text field with a text label generated from a localized title string.
    //    Available when Label is Text.
    init(_ titleKey: LocalizedStringKey, text: Binding<String>,
         onEditingChanged: @escaping (Bool) -> Void = { _ in },
         onCommit: @escaping () -> Void = {},
         onCursorMovement: @escaping (CursorMovement) -> Bool = { _ in return false }
    )
    {
        self.text = text
        self.textField  = BNSTextField(string: self.text)
        self.textField.placeholderString = titleKey.stringValue()
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
        self.onCursorMovement = onCursorMovement

        configure()
    }

    private func configure() {
        textField.onCommit = {
            self.onCommit()
        }
        textField.onEditingChanged = { v in
            onEditingChanged(v)
        }

        textField.onPerformKeyEquivalent = { event in
            if event.keyCode == 126 {
                // up!
                return onCursorMovement(.up)
            } else if event.keyCode == 125 {
                // down!
                return onCursorMovement(.down)
            }
            return false
        }
    }

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        return textField
    }

    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
    }
}
