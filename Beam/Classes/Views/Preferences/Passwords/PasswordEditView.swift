//
//  PasswordEditView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/09/2021.
//

import SwiftUI

struct PasswordEditView: View {
    let entry: PasswordManagerEntry?
    let password: String
    let editType: PasswordEditType
    var onSave: (() -> Void)?

    @State private var hostname = ""
    @State private var username = ""
    @State private var newPassword = ""
    @State private var urlIsNotValid = false
    @Environment(\.presentationMode) private var presentationMode

    enum PasswordEditType {
        case create
        case update
    }

    var body: some View {
        VStack {
            SubmitHandler(action: saveAndDismiss) {
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
                        }
                        .disabled(editType == PasswordEditType.update)
                        if urlIsNotValid {
                            Text("Website URL is invalid")
                                .font(BeamFont.regular(size: 10).swiftUI)
                                .foregroundColor(BeamColor.Shiraz.swiftUI)
                        }
                    }
                    .padding(.bottom, urlIsNotValid ? 0 : 10)
                    HStack {
                        Text("Username:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        TextField("", text: $username)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 10)
                    HStack {
                        Text("Password:")
                            .font(BeamFont.regular(size: 12).swiftUI)
                            .foregroundColor(BeamColor.Generic.subtitle.swiftUI)
                        TextField("", text: $newPassword)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                            .frame(width: 286, height: 19, alignment: .center)
                    }
                    .padding(.bottom, 12)
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                        Button {
                            saveAndDismiss()
                        } label: {
                            Text(editType == PasswordEditType.create ? "Add Password" : "Done")
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }
                        .buttonStyle(.bordered)
                        .disabled(hostname.isEmpty || username.isEmpty || newPassword.isEmpty || urlIsNotValid)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 400, height: 179, alignment: .center)
        .onAppear {
            if let entry = entry {
                hostname = entry.minimizedHost
                username = entry.username
            }
            newPassword = password
        }
    }

    private func saveAndDismiss() {
        guard !hostname.isEmpty, !username.isEmpty, !newPassword.isEmpty else { return }
        let validHostname = hostname.validUrl()
        if validHostname.isValid {
            PasswordManager.shared.save(entry: editType == .update ? entry : nil, hostname: hostname, username: username, password: newPassword)
            dismiss()
            onSave?()
        } else {
            urlIsNotValid = true
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}

private struct SubmitHandler<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var view: () -> Content

    @ViewBuilder
    var body: some View {
        if #available(macOS 12.0, *) {
            Form {
                view()
            }
            .onSubmit(action)
        } else {
            view()
        }
    }
}

struct PasswordEditView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordEditView(entry: nil, password: "", editType: .create)
    }
}
