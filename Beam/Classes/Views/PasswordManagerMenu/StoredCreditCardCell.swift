//
//  StoredCreditCardCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 27/04/2022.
//

import SwiftUI

struct StoredCreditCardCell: View {
    let cardDescription: String
    let obfuscatedNumber: String
    let cardImageName: String
    let isHighlighted: Bool
    let onChange: (WebFieldAutofillMenuCellState) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WebFieldAutofillMenuCell(type: .autofill, height: 56, isHighlighted: isHighlighted, onChange: onChange) {
            HStack(spacing: 12) {
                Image(cardImageName)
                    .renderingMode(.original)
                    .foregroundColor(BeamColor.WebFieldAutofill.icon.swiftUI)
                    .blendMode(colorScheme == .light ? .multiply : .screen)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cardDescription)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.WebFieldAutofill.primaryText.swiftUI)
                    Text(obfuscatedNumber)
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.WebFieldAutofill.secondaryText.swiftUI)
                        .blendMode(colorScheme == .light ? .multiply : .screen)
                }
            }
        }
    }
}

struct StoredCreditCardCell_Previews: PreviewProvider {
    static var previews: some View {
        StoredCreditCardCell(cardDescription: "Personal", obfuscatedNumber: "xxxx-xxxx-xxxx-1234", cardImageName: "autofill-card_visa", isHighlighted: false) { _ in }
    }
}
