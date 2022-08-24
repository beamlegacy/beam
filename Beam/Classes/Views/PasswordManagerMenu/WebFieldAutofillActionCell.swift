//
//  WebFieldAutofillActionCell.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/04/2021.
//

import SwiftUI

struct WebFieldAutofillActionCell: View {
    var label: String
    let isHighlighted: Bool
    var onChange: ((WebFieldAutofillMenuCellState) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    @State private var highlightState: WebFieldAutofillMenuCellState = .idle

    var body: some View {
        WebFieldAutofillMenuCell(type: .action, height: 35, isHighlighted: isHighlighted, onChange: updateHighlightState) {
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

    private func updateHighlightState(_ newState: WebFieldAutofillMenuCellState) {
        highlightState = newState
        onChange?(newState)
    }
}

struct OtherPasswordsCell: View {
    var host: String?
    let isHighlighted: Bool
    var onChange: ((WebFieldAutofillMenuCellState) -> Void)?

    var body: some View {
        WebFieldAutofillActionCell(label: host != nil ? "Other Passwords for \(host!)" : "Other Passwords...", isHighlighted: isHighlighted, onChange: onChange)
    }
}

struct SuggestPasswordCell: View {
    let isHighlighted: Bool
    var onChange: ((WebFieldAutofillMenuCellState) -> Void)?

    var body: some View {
        WebFieldAutofillActionCell(label: "Suggest new password", isHighlighted: isHighlighted, onChange: onChange)
    }
}

struct OtherCreditCardsCell: View {
    let isHighlighted: Bool
    var onChange: ((WebFieldAutofillMenuCellState) -> Void)?

    var body: some View {
        WebFieldAutofillActionCell(label: "Other Credit Cards...", isHighlighted: isHighlighted, onChange: onChange)
    }
}

struct OtherPasswordsCell_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordsCell(isHighlighted: false)
    }
}
