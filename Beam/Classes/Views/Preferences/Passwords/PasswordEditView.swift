//
//  PasswordEditView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/09/2021.
//

import SwiftUI

struct PasswordEditView: View {
    @State var hostname: String
    @State var username: String
    @State var password: String
    var editType: PasswordEditType
    var onSave: (() -> Void)?

    @State private var urlIsNotValid: Bool = false
    @Environment(\.presentationMode) private var presentationMode

    enum PasswordEditType {
        case create
        case update
    }

    var body: some View {
        VStack {
            VStack(alignment: .trailing) {
                VStack(alignment: .trailing) {
                    HStack {
                        Text("Site:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        TextField("", text: $hostname, onEditingChanged: { editing in
                            if editing && urlIsNotValid {
                                urlIsNotValid = false
                            }
                        })
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)

                    }.disabled(editType == PasswordEditType.update)
                    if urlIsNotValid {
                        Text("Website URL is invalid")
                            .font(BeamFont.regular(size: 10).swiftUI)
                            .foregroundColor(BeamColor.Shiraz.swiftUI)
                    }
                }.padding(.bottom, urlIsNotValid ? 0 : 10)
                HStack {
                    Text("Username:")
                        .font(BeamFont.regular(size: 12).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    TextField("", text: $username)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 286, height: 19, alignment: .center)
                }.padding(.bottom, 10)
                HStack {
                    Text("Password:")
                        .font(BeamFont.regular(size: 12).swiftUI)
                        .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    TextField("", text: $password)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .frame(width: 286, height: 19, alignment: .center)
                }.padding(.bottom, 12)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                    Button {
                        let validHostname = hostname.validUrl()
                        if validHostname.isValid {
                            PasswordManager.shared.save(hostname: hostname, username: username, password: password)
                            dismiss()
                            onSave?()
                        } else {
                            urlIsNotValid = true
                        }
                    } label: {
                        Text(editType == PasswordEditType.create ? "Add Password" : "Done")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                        .disabled(hostname.isEmpty || username.isEmpty || password.isEmpty || urlIsNotValid)
                }
            }.padding(20)
          }.frame(width: 400, height: 179, alignment: .center)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct PasswordEditView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordEditView(hostname: "", username: "", password: "", editType: .create)
    }
}
