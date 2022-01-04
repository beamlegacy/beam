//
//  OtherPasswordsCell.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/04/2021.
//

import SwiftUI

struct PasswordActionCell: View {
    var label: String
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    @State private var highlightState: PasswordManagerMenuCellState = .idle

    var body: some View {
        PasswordManagerMenuCell(type: .action, height: 35, onChange: updateHighlightState) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(labelColor)
                    .blendMode(colorScheme == .light ? .multiply : .screen)
            }
        }
    }

    private var labelColor: Color {
        switch highlightState {
        case .idle, .clicked:
            return BeamColor.WebFieldAutofill.actionLabel.swiftUI
        case .hovering:
            return BeamColor.WebFieldAutofill.actionLabelHovered.swiftUI
        case .down:
            return BeamColor.WebFieldAutofill.actionLabelClicked.swiftUI
        }
    }

    private func updateHighlightState(_ newState: PasswordManagerMenuCellState) {
        highlightState = newState
        onChange?(newState)
    }
}

struct OtherPasswordsCell: View {
    var host: String?
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordActionCell(label: host != nil ? "Other Passwords for \(host!)" : "Other Passwords...", onChange: onChange)
    }
}

struct SuggestPasswordCell: View {
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordActionCell(label: "Suggest new password", onChange: onChange)
    }
}

struct OtherPasswordsCell_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordsCell()
    }
}
