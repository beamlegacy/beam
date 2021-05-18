//
//  UserProfileMenu.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 04/05/2021.
//

import SwiftUI

struct UserProfileMenu: View {
    @ObservedObject var viewModel: PasswordManagerMenuViewModel
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading) {
            UserProfileCell(viewModel: viewModel)
                .padding(.leading, 14)
                .padding(.top, 10)
            EditUserInfoCell { newState in
                if newState == .clicked {
                    // Open Preferences
                }
            }
        }
        .frame(width: width)
        .cornerRadius(6)
    }
}

struct UserProfileMenu_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileMenu(viewModel: PasswordManagerMenuViewModel(host: URL(string: "https://beamapp.co")!, passwordStore: MockPasswordStore(), userInfoStore: MockUserInformationsStore(), withPasswordGenerator: false), width: 220)
    }
}

struct UserProfileCell: View {
    var viewModel: PasswordManagerMenuViewModel

    var body: some View {
            VStack(alignment: .leading) {
                Text(viewModel.display.userInfo.email)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .padding(.bottom, BeamSpacing._40)
                HStack {
                    Text(viewModel.display.userInfo.firstName)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                    Text(viewModel.display.userInfo.lastName)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .padding(.leading, -5.0)
                }
                .padding(.bottom, BeamSpacing._40)
                Text(viewModel.display.userInfo.adresses)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
            }
            .frame(maxHeight: 76, alignment: .leading)
    }
}

struct UserProfileCell_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileCell(viewModel: PasswordManagerMenuViewModel(host: URL(string: "https://beamapp.co")!, passwordStore: MockPasswordStore(), userInfoStore: MockUserInformationsStore(), withPasswordGenerator: false))
    }
}

struct EditUserInfoCell: View {
    var onChange: ((PasswordManagerMenuCellState) -> Void)?

    var body: some View {
        PasswordManagerMenuCell(height: 35, onChange: onChange) {
            VStack(alignment: .leading) {
                Separator(horizontal: true)
                Text("Edit Adresses...")
                    .font(BeamFont.medium(size: 12).swiftUI)
                    .foregroundColor(BeamColor.LightStoneGray.swiftUI)
            }
        }
    }
}
