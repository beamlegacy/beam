//
//  SearchPasswordsCell.swift
//  Beam
//
//  Created by Beam on 01/04/2021.
//

import SwiftUI
import BeamCore

struct SearchPasswordsCell: View {
    let active: Bool
    @Binding var searchString: String
    @State private var isEditing = false
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordManagerMenuCell(type: .action, height: 56, onChange: onChange) {
            HStack {
                Icon(name: "field-search", color: BeamColor.Generic.placeholder.swiftUI)
                BeamTextField(text: $searchString,
                              isEditing: $isEditing,
                              placeholder: "Search Passwords",
                              font: BeamFont.regular(size: 13).nsFont,
                              textColor: BeamColor.Generic.text.nsColor,
                              placeholderColor: BeamColor.Generic.placeholder.nsColor)
                    .textFieldStyle(PlainTextFieldStyle())
                    .disableAutocorrection(true)
                    .disabled(!active)
            }
        }
    }
}

struct SearchPasswordsCell_Previews: PreviewProvider {
    static var previews: some View {
        SearchPasswordsCell(active: true, searchString: .constant("test"))
    }
}
