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
    typealias NSViewType = NSScrollView

    @Binding var text: String
    @Binding var isEditing: Bool
    @State var placeholderText: String
    var selectedRanges: [Range<Int>]?
    var onTextChanged: (String) -> Void = { _ in }
    var onCommit: () -> Void = { }
    var onEscape: () -> Void = { }
    var onCursorMovement: (CursorMovement) -> Bool = { _ in false }
    @State var focusOnCreation: Bool
    @State var textColor: NSColor?
    @State var placeholderTextColor: NSColor?
    var name: String?

    func makeNSView(context: Self.Context) -> Self.NSViewType {
        let textField = BNSTextField(string: $text, focusOnCreation: focusOnCreation, name: name)

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
            } else if event.keyCode == 53 {
                onEscape()
                return true
            }
//            print("key \(event.keyCode)")

            return false
        }
        textField.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.documentView = textField
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ nsView: Self.NSViewType, context: Self.Context) {
        // swiftlint:disable:next force_cast
        let textField = nsView.documentView as! BNSTextField
        textField.string = text
        textField.placeholderText = placeholderText
        if let c = textColor {
            textField.textColor = c
        }
        if let c = placeholderTextColor {
            textField.placeholderTextColor = c
        }
        textField.focusOnCreation = self.focusOnCreation

        if let selectedRanges = self.selectedRanges {
            textField.inSelectionUpdate = true
            let ranges = selectedRanges.map({ range -> NSValue in
                let pos = Int(range.startIndex)
                let len = Int(range.endIndex - range.startIndex)
                return NSValue(range: NSRange(location: pos, length: len))
            })
            textField.selectedRanges = ranges
            textField.inSelectionUpdate = false
        }
    }
}
