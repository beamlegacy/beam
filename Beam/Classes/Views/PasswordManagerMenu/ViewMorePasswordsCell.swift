//
//  PasswordsViewMoreCell.swift
//  Beam
//
//  Created by Beam on 01/04/2021.
//

import SwiftUI

struct PasswordsViewMoreCell: View {
    let count: Int
    let onChange: (PasswordManagerMenuCellState) -> Void

    var body: some View {
        PasswordManagerMenuCell(onChange: onChange) {
            Text("View \(count) more…")
        }
    }
}

struct PasswordsViewMoreCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsViewMoreCell(count: 2) { _ in }
    }
}
