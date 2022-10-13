//
//  OtherPasswordsModal.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 27/04/2021.
//

import SwiftUI

struct OtherPasswordModal: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var searchString = ""
    @State private var isEditing = true
    @State private var showingAlert = false
    @State private var selectedEntries = IndexSet()
    @State private var editedPassword: PasswordListViewModel.EditedPassword?
    @State private var alertMessage: PasswordListViewModel.AlertMessage?

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
            .foregroundColor(BeamColor.Generic.background.swiftUI)
            Spacer()
            PasswordsTableView(passwordEntries: viewModel.filteredPasswordTableViewItems) { idx in
                viewModel.updateSelection(idx)
            } onDoubleTap: { row in
                do {
                    let entry = viewModel.filteredPasswordEntries[row]
                    let password = try BeamData.shared.passwordManager.password(hostname: entry.minimizedHost, username: entry.username, markUsed: false)
                    editedPassword = PasswordListViewModel.EditedPassword(entry: entry, password: password)
                } catch {
                    alertMessage = .init(error: error)
                }
            }
            .frame(width: 528, height: 240, alignment: .center)
            .border(BeamColor.Generic.tableViewStroke.swiftUI, width: 1)
            .background(BeamColor.Generic.tableViewBackground.swiftUI)
            .sheet(item: $editedPassword) {
                PasswordEditView(entry: $0.entry, password: $0.password, editType: .update)
                    .frame(width: 400, height: 179, alignment: .center)
            }
            .alert(item: $alertMessage) {
                Alert(title: Text($0.message))
            }
            Spacer()
            HStack {
                OtherPasswordModalButton(title: "Remove", isDisabled: viewModel.disableRemoveButton) {
                    self.showingAlert.toggle()
                }
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text(removeAlertMessage(for: viewModel.selectedEntries)),
                          primaryButton: .destructive(Text("Remove"), action: {
                        onRemove(viewModel.selectedEntries)
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
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .if(!viewModel.isUnlocked) {
            $0.opacity(0)
        }
        .onAppear {
            Task {
                await viewModel.checkAuthentication()
                if !viewModel.isUnlocked {
                    dismiss()
                }
            }
        }
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

struct OtherPasswordsSheet: View {
    @ObservedObject var viewModel: PasswordListViewModel

    var onFill: ((PasswordManagerEntry) -> Void)
    var onRemove: (([PasswordManagerEntry]) -> Void)
    var onDismiss: (() -> Void)

    let width = 568.0
    let height = 361.0

    var body: some View {
        FormatterViewBackground(boxCornerRadius: 10, shadowOpacity: 0) {
            OtherPasswordModal(viewModel: viewModel, onFill: onFill, onRemove: onRemove, onDismiss: onDismiss)
                .background(Color.clear)
                .frame(width: width, height: height, alignment: .center)
        }
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
        OtherPasswordModal(viewModel: PasswordListViewModel(passwordManager: PasswordManager(objectManager: BeamObjectManager()), showNeverSavedEntries: true),
                           onFill: { _ in },
                           onRemove: { _ in },
                           onDismiss: {})

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
                .frame(width: 72, alignment: .center)
        })
        .disabled(isDisabled)
        .buttonStyle(.bordered)
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
