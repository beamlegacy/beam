//
//  PasswordGeneratorSuggestionCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

enum PasswordGeneratorAction {
    case generate
    case togglePreferences
}

struct PasswordGeneratorSuggestionCell: View {
    @ObservedObject var viewModel: PasswordGeneratorViewModel

    var body: some View {
        PasswordManagerMenuCell(onChange: handleStateChange) {
            HStack {
                Icon(name: "password-key", color: BeamColor.Generic.text.swiftUI)
                VStack(alignment: .leading) {
                    Text("Password Suggestion")
                        .fontWeight(.bold)
                    Text(viewModel.suggestion)
                }
                Spacer()
                Button(action: viewModel.generate, label: {
                    Icon(name: "password-generate", color: BeamColor.Generic.text.swiftUI)
                })
                .buttonStyle(PlainButtonStyle())
                Button(action: viewModel.togglePreferences, label: {
                    Icon(name: "password-preferences", color: BeamColor.Generic.text.swiftUI)
                })
                .buttonStyle(PlainButtonStyle())
            }
        }
        .onAppear {
            viewModel.generate()
        }
    }

    private func handleStateChange(newState: PasswordManagerMenuCellState) {
        if newState == .clicked {
            viewModel.clicked()
        }
    }
}

struct PasswordGeneratorSuggestionCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorSuggestionCell(viewModel: PasswordGeneratorViewModel())
    }
}
