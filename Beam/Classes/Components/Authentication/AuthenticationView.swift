//
//  AuthenticationView.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 26/07/2021.
//

import SwiftUI

struct AuthenticationView: View {

    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var focused = 0

    var body: some View {
        VStack(alignment: .leading) {
            Text("Connect to \(viewModel.serverDescription)")
                .font(BeamFont.medium(size: 14).swiftUI)
                .padding(.bottom, 1)
            Text(viewModel.securityMessage)
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                .padding(.bottom)
            FocusableTextField(placeholder: "User name", text: $viewModel.username, autoFocus: true, tag: 0, focusTag: $focused, onTabKeystroke: {
                focused = 1
            })
            FocusableTextField(placeholder: "Password", text: $viewModel.password, secured: true, tag: 1, focusTag: $focused, onTabKeystroke: {
                focused = 0
            }, onReturnKeystroke: {
                viewModel.validate()
            })
            Toggle(isOn: $viewModel.savePassword, label: {
                Text("Save login details")
            })
            Separator(horizontal: true, hairline: true)
                .padding(.top)
            HStack {
                Spacer()
                ButtonLabel("Cancel", variant: .secondary) {
                    viewModel.cancel()
                }
                ButtonLabel("Connect", variant: .primary) {
                    viewModel.validate()
                }
            }
        }
        .padding()
        .frame(width: 440, alignment: .center)
        .background(BeamColor.Generic.background.swiftUI)
        .cornerRadius(6)
        .shadow(radius: 3)
        .id(viewModel)
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView(viewModel: .init(host: "www.beamapp.co", port: 443, isSecured: true, onValidate: { _, _, _  in

        }, onCancel: {

        }))
    }
}
