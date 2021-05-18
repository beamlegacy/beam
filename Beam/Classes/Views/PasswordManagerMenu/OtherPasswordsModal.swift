//
//  OtherPasswordsModal.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/04/2021.
//

import SwiftUI

struct OtherPasswordModal: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var searchString: String = ""
    @State private var isEditing: Bool = true
    @State private var passwordSelected: Bool = false
    @State private var multipleSelection: Bool = false
    @State private var showingAlert: Bool = false
    @State private var selectedEntries = IndexSet()

    @State var passwordEntries: [PasswordManagerEntry]
    var onFill: ((PasswordManagerEntry) -> Void)
    var onRemove: ((PasswordManagerEntry) -> Void)
    var onDismiss: (() -> Void)

    var body: some View {
        VStack {
            HStack {
                Text("Choose a login to fill")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.medium(size: 13).swiftUI)
                Spacer()
                HStack {
                    Icon(name: "field-search", size: 16, color: BeamColor.Generic.placeholder.swiftUI)
                        .frame(width: 16)
                    BeamTextField(text: $searchString,
                                  isEditing: $isEditing,
                                  placeholder: "Search",
                                  font: BeamFont.regular(size: 13).nsFont,
                                  textColor: BeamColor.Generic.text.nsColor,
                                  placeholderColor: BeamColor.Generic.placeholder.nsColor)
                        .disableAutocorrection(true)
                }
                .frame(width: 217, height: 20, alignment: .center)
                .padding(.horizontal, 2)
                .padding(.leading, 6.5)
                .border(Color.black.opacity(0.1), width: 1)
                .cornerRadius(4)
            }
            Spacer()
            PasswordsTableView(passwordEntries: passwordEntries, searchStr: searchString,
                               passwordSelected: $passwordSelected, onSelectionChanged: { idx in
                                DispatchQueue.main.async {
                                    self.multipleSelection = idx.count > 1
                                    self.selectedEntries = idx
                                }
                               })
                .frame(width: 528, height: 240, alignment: .center)
                .border(BeamColor.Mercury.swiftUI, width: 1)
                .background(BeamColor.Generic.background.swiftUI)
            Spacer()
            HStack {
                OtherPasswordModalButton(title: "Remove") {
                    self.showingAlert.toggle()
                }.disabled(!passwordSelected)
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("Are you sure you want to remove the login details for \(passwordEntries[selectedEntries.first ?? 0].username) for \(passwordEntries[selectedEntries.first ?? 0].host) ?"),
                          primaryButton: .destructive(Text("Remove"), action: {
                            guard let index = selectedEntries.first else { return }
                            onRemove(passwordEntries[index])
                          }),
                          secondaryButton: .cancel(Text("Cancel")))
                }
                Spacer()
                HStack {
                    OtherPasswordModalButton(title: "Cancel") {
                        dismiss()
                    }
                    OtherPasswordModalButton(title: "Fill") {
                        guard let index = selectedEntries.first else { return }
                        onFill(passwordEntries[index])
                        dismiss()
                    }.disabled(!passwordSelected || multipleSelection)
                }
            }
        }
        .foregroundColor(BeamColor.Generic.background.swiftUI)
        .padding(20)
    }

    private func dismiss() {
        onDismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

struct OtherPasswordModal_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordModal(passwordEntries: [], onFill: { _ in }, onRemove: { _ in }, onDismiss: {})
    }
}

struct OtherPasswordModalButton: View {
    var title: String
    var action:() -> Void

    var body: some View {
        Button(action: action, label: {
            Text(title)
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 72, height: 20, alignment: .center)
        })
        .buttonStyle(BorderedButtonStyle())
        .foregroundColor(BeamColor.Generic.background.swiftUI)
    }
}

struct OtherPassorwdModalButton_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordModalButton(title: "Remove") {
        }
    }
}
