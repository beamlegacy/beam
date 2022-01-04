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
        VStack(alignment: .leading, spacing: 0) {
            Text("Suggested Password")
                .font(BeamFont.semibold(size: 14).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.bottom, 8)
            Text("Beam created a strong password for this website.\nLook up your saved passwords in Beam Passwords preferences.")
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.bottom, 24)
            Spacer(minLength: BeamSpacing._20)
            VStack(alignment: .trailing) {
                HStack(spacing: 16) {
                    Spacer()
                    ActionableButton(text: "Don't Use", defaultState: .normal, variant: .secondary, height: 26) {
                        viewModel.dontUsePassword()
                    }
                    ActionableButton(text: "Use Password", defaultState: .normal, variant: .primaryBlue, height: 26) {
                        viewModel.usePassword()
                    }
                }
            }
        }.padding(16)
        .onAppear {
            viewModel.start()
        }
    }
}

struct PasswordGeneratorSuggestionCell_Previews: PreviewProvider {
    static var previews: some View {
        PasswordGeneratorSuggestionCell(viewModel: PasswordGeneratorViewModel())
    }
}
