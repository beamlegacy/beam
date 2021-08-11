//
//  PasswordGeneratorSuggestionCell.swift
//  Beam
//
//  Created by Frank Lefebvre on 02/04/2021.
//

import SwiftUI

struct PasswordGeneratorSuggestionCell: View {
    @ObservedObject var viewModel: PasswordGeneratorViewModel
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Icon(name: "password-key", color: BeamColor.Generic.text.swiftUI)
                Text("Beam created a password for this site.")
                    .font(BeamFont.medium(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            }
            Spacer(minLength: BeamSpacing._20)
            VStack(alignment: .trailing) {
                HStack {
                    Spacer()
                    ButtonLabel("Don't use", icon: nil, state: .normal, variant: .secondary) {
                        viewModel.emptyPasswordField()
                    }
                    ButtonLabel("Use Password", icon: nil, state: .normal, variant: .primary) {
                        viewModel.dismiss()
                    }
                }
            }
        }.padding()
        .onAppear {
            viewModel.generate()
            viewModel.clicked()
        }
    }
}

struct PasswordGeneratorSuggestionCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorSuggestionCell(viewModel: PasswordGeneratorViewModel())
    }
}
