//
//  PasswordsViewMoreCell.swift
//  Beam
//
//  Created by Beam on 01/04/2021.
//

import SwiftUI

struct PasswordsViewMoreCell: View {
    var hostName: String
    let onChange: (PasswordManagerMenuCellState) -> Void

    var body: some View {
        PasswordManagerMenuCell(height: 35, onChange: onChange) {
            VStack(alignment: .leading) {
                Text("Other Passwords for \(hostName)")
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
        }
    }
}

struct PasswordsViewMoreCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsViewMoreCell(hostName: "www.github.com") { _ in }
    }
}
