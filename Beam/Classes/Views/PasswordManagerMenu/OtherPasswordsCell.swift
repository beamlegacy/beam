//
//  OtherPasswordsCell.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/04/2021.
//

import SwiftUI

struct OtherPasswordsCell: View {
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordManagerMenuCell(height: 35, onChange: onChange) {
            VStack(alignment: .leading) {
                Text("Other Passwords...")
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
        }
    }
}

struct OtherPasswordsCell_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordsCell()
    }
}
