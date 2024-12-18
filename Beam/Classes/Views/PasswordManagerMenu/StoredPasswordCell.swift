//
//  StoredPasswordCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 30/03/2021.
//

import SwiftUI

struct StoredPasswordCell: View {
    let host: String
    let username: String
    let isHighlighted: Bool
    let onChange: (WebFieldAutofillMenuCellState) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        WebFieldAutofillMenuCell(type: .autofill, height: 56, isHighlighted: isHighlighted, onChange: onChange) {
            HStack(spacing: 12) {
                Image("autofill-password")
                    .renderingMode(.template)
                    .foregroundColor(BeamColor.WebFieldAutofill.icon.swiftUI)
                    .blendMode(colorScheme == .light ? .multiply : .screen)
                VStack(alignment: .leading, spacing: 3) {
                    Text(username)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.WebFieldAutofill.primaryText.swiftUI)
                    Text(host)
                        .font(BeamFont.regular(size: 11).swiftUI)
                        .foregroundColor(BeamColor.WebFieldAutofill.secondaryText.swiftUI)
                        .blendMode(colorScheme == .light ? .multiply : .screen)
                }
            }
        }
    }
}

struct StoredPasswordCell_Previews: PreviewProvider {
    static var previews: some View {
        StoredPasswordCell(host: "beamapp.co", username: "beam@beamapp.co", isHighlighted: false) { _ in }
    }
}
