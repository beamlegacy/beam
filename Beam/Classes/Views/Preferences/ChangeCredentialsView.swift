//
//  ChangeCredentialsView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/09/2021.
//

import Foundation
import SwiftUI
import BeamCore

struct ChangeCredentialsView: View {
    enum ChangeCredentialType {
        case email
        case password
    }

    @Environment(\.presentationMode) var presentationMode
    var changeCredentialsType: ChangeCredentialType

    @State var email: String = ""
    @State var oldPassword: String = ""
    @State var newPassword: String = ""
    @State var newPasswordEditing: Bool = false
    @State var newPasswordIsValid: Bool = false
    @State var oldPasswordIsWrong: Bool = false

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Image("preferences-about-beam")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52, alignment: .top)
                        .padding([.top, .leading], 26)
                    Spacer()
                }

                switch changeCredentialsType {
                case .email:
                    changeEmailView
                case .password:
                    changePasswordView
                }
            }
        }.frame(width: 486, height: changeCredentialsType == .email ? 151 : 198, alignment: .center)
    }

    var changeEmailView: some View {
        VStack(alignment: .trailing) {
            Text("Enter your new email address to receive a confirmation email to validate it.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .font(BeamFont.bold(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 371, height: 32, alignment: .leading)
            HStack(alignment: .center, spacing: 9) {
                Text("New Email Address:")
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(maxWidth: 130, alignment: .leading)
                TextField("", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 232)
            }.frame(maxWidth: 371)
                .padding(.bottom, 20)

            Spacer()
            VStack(alignment: .trailing) {
                HStack(alignment: .bottom) {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 42, height: 16, alignment: .center)
                    }.buttonStyle(BorderedButtonStyle())

                    Button {
                        // change email func call
                    } label: {
                        Text("Change Email Address")
                            .frame(width: 141, height: 16, alignment: .center)
                    }.buttonStyle(BorderedButtonStyle())
                        .disabled(email.isEmpty)
                }
            }
        }.padding([.top, .bottom, .trailing], 20)
    }

    var changePasswordView: some View {
        VStack(alignment: .trailing) {
            Text("Enter your current and a new password to change it.")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .font(BeamFont.bold(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 371, height: 32, alignment: .leading)

            HStack(alignment: .center) {
                Text("Current Password:")
                    .lineLimit(nil)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 115, alignment: .trailing)
                Spacer()
                TextField("", text: $oldPassword) { editing in
                    if editing && oldPasswordIsWrong {
                        oldPasswordIsWrong.toggle()
                    }
                }.textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 242, alignment: .trailing)
            }.frame(maxWidth: 371)

            HStack(alignment: .center) {
                Text("New Password:")
                    .lineLimit(nil)
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .frame(width: 115, alignment: .trailing)
                Spacer()
                TextField("", text: $newPassword, onEditingChanged: { editing in
                    newPasswordEditing = editing
                })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 242, alignment: .trailing)
            }.frame(maxWidth: 371)

            if oldPasswordIsWrong {
                Text("Current password doesn’t match")
                    .font(BeamFont.medium(size: 10).swiftUI)
                    .foregroundColor(BeamColor.Shiraz.swiftUI)
                    .frame(width: 242, height: 12, alignment: .leading)
            } else {
                validator(newPassword: newPassword, editing: newPasswordEditing)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .font(BeamFont.medium(size: 10).swiftUI)
                    .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                    .frame(width: 242, height: 24, alignment: .leading)
            }

            Spacer()
            VStack(alignment: .trailing) {
                HStack(alignment: .bottom) {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(width: 42, height: 16, alignment: .center)
                    }.buttonStyle(BorderedButtonStyle())
                    Button {
                        // change Password func call
                        // if error
                        oldPasswordIsWrong.toggle()
                    } label: {
                        Text("Change Password")
                            .frame(width: 113, height: 16, alignment: .center)
                    }.buttonStyle(BorderedButtonStyle())
                        .disabled(newPassword.isEmpty || oldPassword.isEmpty || !newPasswordIsValid || oldPasswordIsWrong)
                }
            }
        }.padding([.top, .bottom, .trailing], 20)
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }

    private func validator(newPassword: String, editing: Bool) -> Text {
        DispatchQueue.main.async {
            newPasswordIsValid = newPassword.count >= 8 && newPassword.containsSymbol && newPassword.containsDigit
        }
        let green = Color(red: 0.03, green: 0.53, blue: 0.39, opacity: 1.00)
        let yellow = Color(red: 1.00, green: 0.60, blue: 0.01, opacity: 1.00)

        let firstSplit = Text("Use at least ")
        let charSplit = editing ? Text("8 characters").foregroundColor(newPassword.count >= 8 ? green : yellow) : Text("8 characters")
        let secondSplit = Text(", ")
        let symbolSplit = editing ? Text("one symbol").foregroundColor(newPassword.containsSymbol ? green : yellow) : Text("one symbol")
        let thirdSplit = Text(" and ")
        let numberSplit = editing ? Text("one number").foregroundColor(newPassword.containsDigit ? green : yellow) : Text("one number")

        return firstSplit + charSplit + secondSplit + symbolSplit + thirdSplit + numberSplit
    }
}

struct ChangeCredentialsView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeCredentialsView(changeCredentialsType: .email)
        ChangeCredentialsView(changeCredentialsType: .password)

    }
}
