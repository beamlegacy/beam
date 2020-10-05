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

    @Binding var text: String
    @Binding var isEditing: Bool
    @State var placeholderText: String
    var selectedRanges: [Range<Int>]?
    var onTextChanged: (String) -> Void = { _ in }
    var onCommit: () -> Void = { }
    var onCursorMovement: (CursorMovement) -> Bool = { _ in false }
    @State var focusOnCreation: Bool
    @State var textColor: NSColor?
    @State var placeholderTextColor: NSColor?


    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let textField = BNSTextField(string: $text, focusOnCreation: focusOnCreation)

        textField.focusRingType = .none
        textField.onCommit = self.onCommit
        textField.onTextChanged = self.onTextChanged
        textField.onEditingChanged = { v in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.3, blendDuration: 0.5)) {
                self.isEditing = v
            }
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

        return textField
    }

    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
        nsView.string = text
        nsView.placeholderText = placeholderText
        if let c = textColor {
            nsView.textColor = c
        }
        if let c = placeholderTextColor {
            nsView.placeholderTextColor = c
        }
        nsView.focusOnCreation = self.focusOnCreation

        if let selectedRanges = self.selectedRanges {
            nsView.inSelectionUpdate = true
            let ranges = selectedRanges.map({ range -> NSValue in
                let pos = Int(range.startIndex)
                let len = Int(range.endIndex - range.startIndex)
                return NSValue(range: NSRange(location: pos, length: len))
            })
            nsView.selectedRanges = ranges
            nsView.inSelectionUpdate = false
        }
    }
}


