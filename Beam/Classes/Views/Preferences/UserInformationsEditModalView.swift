//
//  UserInformationsEditModalView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 08/07/2021.
//

import Foundation
import SwiftUI

struct UserInformationsEditModalView: View {
    @Environment(\.presentationMode) var presentationMode

    @State var country: String
    @State var organization: String
    @State var firstName: String
    @State var lastName: String
    @State var postalCode: String
    @State var city: String
    @State var phone: String
    @State var email: String
    @State var adress: String
    var onSave: (UserInformations) -> Void

    @State var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("New Address")
                .font(BeamFont.semibold(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .padding(.leading, 20)
                .padding(.top, 10)

            HStack {
                Text("Country:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)
                TextField(country, text: $country)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 163, height: 19, alignment: .trailing)

            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Organization:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                TextField(organization, text: $organization)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("First Name:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                TextField(firstName, text: $firstName)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Last Name:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                TextField(lastName, text: $lastName)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Adresse:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                BeamTextField(text: $adress,
                              isEditing: $isEditing,
                              placeholder: "",
                              font: BeamFont.regular(size: 13).nsFont,
                              textColor: BeamColor.Generic.text.nsColor,
                              placeholderColor: BeamColor.Generic.text.nsColor)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 94, alignment: .center)
                    .border(Color.gray, width: 1)
                    .cornerRadius(4)

            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Postal Code:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)
                TextField(postalCode, text: $postalCode)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 114, height: 19, alignment: .center)

                Text("City:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 41, alignment: .trailing)

                TextField(city, text: $city)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 114, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Phone:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                TextField(phone, text: $phone)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Text("Email:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 121, alignment: .trailing)

                TextField(email, text: $email)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .disableAutocorrection(true)
                    .frame(width: 286, height: 19, alignment: .center)
            }.textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top, 10)

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 72, height: 20, alignment: .center)
                }.buttonStyle(BorderedButtonStyle())

                Button {
                    onSave(UserInformations(country: 1, organization: organization, firstName: firstName, lastName: lastName, adresses: adress, postalCode: postalCode, city: city, phone: phone, email: email))
                    dismiss()
                } label: {
                    Text("Save")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 72, height: 20, alignment: .center)
                }.buttonStyle(BorderedButtonStyle())

            }.padding(.top, 20)
            .padding(.bottom, 10)
            .padding(.trailing, 20)

        }.frame(width: 440, height: 469)
        .foregroundColor(BeamColor.Generic.background.swiftUI)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct UserInformationsEditModalView_Previews: PreviewProvider {
    static var previews: some View {
        UserInformationsEditModalView(country: "France", organization: "Beam", firstName: "John", lastName: "Beam", postalCode: "69001", city: "BeamCity", phone: "0606060606", email: "John@beamapp.co", adress: "123 Rue de Beam", onSave: { _ in })
    }
}
