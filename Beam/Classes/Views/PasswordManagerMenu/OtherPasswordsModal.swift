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
    @State private var showingAlert: Bool = false
    @State private var selectedEntries = IndexSet()

    @ObservedObject var viewModel: PasswordListViewModel

    var onFill: ((PasswordManagerEntry) -> Void)
    var onRemove: (([PasswordManagerEntry]) -> Void)
    var onDismiss: (() -> Void)

    var body: some View {
        VStack {
            HStack {
                Text("Choose a login to fill")
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .font(BeamFont.medium(size: 13).swiftUI)
                Spacer()
                BeamSearchField(searchStr: $searchString, isEditing: $isEditing, placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor, onEscape: {
                    dismiss()
                })
                .frame(width: 220, height: 21, alignment: .center)
                .onChange(of: searchString) {
                    viewModel.searchString = $0
                }
            }
            Spacer()
            PasswordsTableView(passwordEntries: viewModel.filteredPasswordTableViewItems,
                               onSelectionChanged: { idx in
                                viewModel.updateSelection(idx)
                               })
                .frame(width: 528, height: 240, alignment: .center)
                .border(BeamColor.Mercury.swiftUI, width: 1)
                .background(BeamColor.Generic.background.swiftUI)
            Spacer()
            HStack {
                OtherPasswordModalButton(title: "Remove", isDisabled: viewModel.disableRemoveButton) {
                    self.showingAlert.toggle()
                }
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text(removeAlertMessage(for: viewModel.selectedEntries)),
                          primaryButton: .destructive(Text("Remove"), action: {
                            onRemove(viewModel.selectedEntries)
                            viewModel.refresh()
                          }),
                          secondaryButton: .cancel(Text("Cancel")))
                }
                Spacer()
                HStack {
                    OtherPasswordModalCancelButton(title: "Cancel", isDisabled: false) {
                        dismiss()
                    }
                    OtherPasswordModalButton(title: "Fill", isDisabled: viewModel.disableFillButton) {
                        guard let selectedEntry = viewModel.selectedEntries.first else { return }
                        onFill(selectedEntry)
                        dismiss()
                    }
                }
            }
        }
        .foregroundColor(BeamColor.Generic.background.swiftUI)
        .padding(20)
    }

    private func removeAlertMessage(for entries: [PasswordManagerEntry]) -> String {
        if entries.count == 1, let entry = entries.first {
            return "Are you sure you want to remove the login details \(entry.username) for \(entry.minimizedHost)?"
        } else {
            return "Are you sure you want to remove the login details for \(entries.count) accounts?"
        }
    }

    private func dismiss() {
        onDismiss()
        presentationMode.wrappedValue.dismiss()
    }
}

fileprivate extension Sequence where Element == (offset: Int, element: PasswordTableViewItem) {
    func filtered(by searchStr: String) -> [Element] {
        guard !searchStr.isEmpty else {
            return Array(self)
        }
        return filter { (_, item) in
            item.username.contains(searchStr) || item.hostname.contains(searchStr)
        }
    }
}

struct OtherPasswordModal_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordModal(viewModel: PasswordListViewModel(), onFill: { _ in }, onRemove: { _ in }, onDismiss: {})

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

struct OtherPasswordModalCancelButton: View {
    var title: String
    let isDisabled: Bool
    var action:() -> Void

    var body: some View {
        OtherPasswordModalButton(title: title, isDisabled: isDisabled, action: action)
            .keyboardShortcut(.cancelAction)
    }
}

struct OtherPassorwdModalButton_Previews: PreviewProvider {
    static var previews: some View {
        OtherPasswordModalButton(title: "Remove", isDisabled: false) {}
        OtherPasswordModalButton(title: "Remove", isDisabled: true) {}
    }
}
