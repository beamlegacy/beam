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
                BeamSearchField(searchStr: $searchString, isEditing: $isEditing, placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor)
                    .frame(width: 220, height: 21, alignment: .center)
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
                OtherPasswordModalButton(title: "Remove", isDisabled: !passwordSelected) {
                    self.showingAlert.toggle()
                }
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("Are you sure you want to remove the login details \(passwordEntries[selectedEntries.first ?? 0].username) for \(passwordEntries[selectedEntries.first ?? 0].minimizedHost) ?"),
                          primaryButton: .destructive(Text("Remove"), action: {
                            guard let index = selectedEntries.first else { return }
                            onRemove(passwordEntries[index])
                          }),
                          secondaryButton: .cancel(Text("Cancel")))
                }
                Spacer()
                HStack {
                    OtherPasswordModalButton(title: "Cancel", isDisabled: false) {
                        dismiss()
                    }
                    OtherPasswordModalButton(title: "Fill", isDisabled: (!passwordSelected || multipleSelection)) {
                        guard let index = selectedEntries.first else { return }
                        onFill(passwordEntries[index])
                        dismiss()
                    }
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
    let isDisabled: Bool
    var action:() -> Void

    var body: some View {
        Button(action: action, label: {
            Text(title)
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .frame(width: 72, alignment: .center)
        })
        .disabled(isDisabled)
        .buttonStyle(BorderedButtonStyle())
        .foregroundColor(BeamColor.Generic.background.swiftUI)
        .opacity(isDisabled ? 0.35 : 1)
    }
}

struct OtherPassorwdModalButton_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordModalButton(title: "Remove", isDisabled: false) {}
        OtherPasswordModalButton(title: "Remove", isDisabled: true) {}
    }
}
