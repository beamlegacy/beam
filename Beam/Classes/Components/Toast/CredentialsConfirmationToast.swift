//
//  CredentialsConfirmationToast.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 30/04/2021.
//

import SwiftUI

struct CredentialsConfirmationToast: View {
    let saved: Bool

    var body: some View {
        HStack {
            Icon(name: "autofill-password_xs", color: BeamColor.Generic.text.swiftUI)
            Text(saved ? "Username & Password Saved" : "Username & Password Updated")
                .font(BeamFont.medium(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .accessibility(addTraits: .isStaticText)
                .accessibility(identifier: "CredentialsConfirmationToast")
        }.padding()
    }
}

struct CredentialsConfirmationToast_Previews: PreviewProvider {
    static var previews: some View {
        CredentialsConfirmationToast(saved: false)
    }
}
