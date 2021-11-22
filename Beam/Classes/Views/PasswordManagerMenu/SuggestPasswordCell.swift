//
//  SuggestPasswordCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 20/10/2021.
//

import SwiftUI

struct SuggestPasswordCell: View {
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordManagerMenuCell(height: 35, onChange: onChange) {
            VStack(alignment: .leading) {
                Text("Suggest new password")
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
        }
    }
}

struct SuggestPasswordCell_Previews: PreviewProvider {
    static var previews: some View {
        SuggestPasswordCell { _ in }
    }
}
