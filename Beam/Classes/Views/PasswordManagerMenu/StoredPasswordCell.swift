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
    let onChange: (PasswordManagerMenuCellState) -> Void

    var body: some View {
        PasswordManagerMenuCell(height: 56, onChange: onChange) {
            HStack {
                FaviconView(url: URL(string: "https://\(host)"))
                VStack(alignment: .leading) {
                    Text(username)
                        .offset(y: 10)
                        .padding(.bottom, 4)
                    Text("••••••••••••")
                        .padding(.bottom, 10)
                }
            }
        }
    }
}

struct StoredPasswordCell_Previews: PreviewProvider {
    static var previews: some View {
        StoredPasswordCell(host: "beamapp.co", username: "beam@beamapp.co") { _ in }
    }
}
