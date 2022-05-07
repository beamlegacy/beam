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
    let onChange: (PasswordManagerMenuCellState) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PasswordManagerMenuCell(type: .autofill, height: 56, onChange: onChange) {
            HStack(spacing: 12) {
                Image("preferences-credit_card") // FIXME: add asset
                    .renderingMode(.template)
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
        StoredCreditCardCell(cardDescription: "Personal", obfuscatedNumber: "Visa xxxx-1234") { _ in }
    }
}
