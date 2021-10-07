//
//  PasswordsPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import Preferences
import BeamCore

let PasswordsPreferencesViewController: PreferencePane = PreferencesPaneBuilder.build(identifier: .passwords, title: "Passwords", imageName: "preferences-passwords") {
    PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel())
}

struct PasswordsPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth
    var passwordsViewModel: PasswordListViewModel

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                Passwords(passwordsViewModel: passwordsViewModel)
                    .onAppear {
                        passwordsViewModel.refresh()
                    }
            }
            Preferences.Section {
                Text("").labelsHidden()
            } content: {
                Webforms()
            }
        }
    }
}

struct PasswordsPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel())
    }
}

struct Passwords: View {
    @ObservedObject var passwordsViewModel: PasswordListViewModel

    @State var searchString: String = ""
    @State var isEditing: Bool = false

    @State private var selectedEntries = IndexSet()
    @State private var passwordSelected: Bool = false
    @State private var multipleSelection: Bool = false

    @State private var showingAddPasswordSheet: Bool = false
    @State private var showingEditPasswordSheet: Bool = false

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                HStack {
                    Checkbox(checkState: PreferencesManager.autofillUsernamePasswords, text: "Autofill username and passwords", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                        PreferencesManager.autofillUsernamePasswords = activated
                    }
                    Spacer()
                    BeamSearchField(searchStr: $searchString, isEditing: $isEditing, placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor)
                        .frame(width: 220, height: 21, alignment: .center)
                        .onUpdate(of: searchString) { searchString in
                            passwordsViewModel.searchString = searchString
                        }
                }
                HStack {
                    Spacer()
                    PasswordsTableView(passwordEntries: passwordsViewModel.filteredPasswordTableViewItems, onSelectionChanged: { idx in
                        passwordsViewModel.updateSelection(idx)
                    })
                    .frame(width: 682, height: 240, alignment: .center)
                    .border(BeamColor.Mercury.swiftUI, width: 1)
                    .background(BeamColor.Generic.background.swiftUI)
                    Spacer()
                }
                HStack {
                    Button {
                        showingAddPasswordSheet = true
                    } label: {
                        Image("basicAdd")
                            .renderingMode(.template)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                        .sheet(isPresented: $showingAddPasswordSheet) {
                            PasswordEditView(hostname: "",
                                             username: "",
                                             password: "", editType: .create) {
                                passwordsViewModel.refresh()
                            }.frame(width: 400, height: 179, alignment: .center)
                        }
                    Button {
                        promptDeletePasswordsAlert()
                    } label: {
                        Image("basicRemove")
                            .renderingMode(.template)
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                        .disabled(passwordsViewModel.selectedEntries.count == 0)

                    Button {
                        showingEditPasswordSheet = true
                    } label: {
                        Text("Details...")
                            .foregroundColor(BeamColor.Generic.text.swiftUI)
                    }.buttonStyle(BorderedButtonStyle())
                        .sheet(isPresented: $showingEditPasswordSheet) {
                            if let entry = passwordsViewModel.selectedEntries.first,
                               let password = PasswordManager.shared.password(hostname: entry.minimizedHost, username: entry.username) {
                                PasswordEditView(hostname: entry.minimizedHost,
                                                 username: entry.username,
                                                 password: password, editType: .update) {
                                    passwordsViewModel.refresh()
                                }
                            }
                        }
                        .disabled(passwordsViewModel.selectedEntries.count == 0 || passwordsViewModel.selectedEntries.count > 1)
                    Spacer()
                    HStack {
                        Button {
                            importPasswordAction(completion: {
                                passwordsViewModel.refresh()
                            })
                        } label: {
                            Text("Import...")
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                        Button {
                            exportPasswordAction()
                        } label: {
                            Text("Export...")
                                .font(BeamFont.regular(size: 13).swiftUI)
                                .foregroundColor(BeamColor.Generic.text.swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                    }
                }
            }.frame(width: 682, alignment: .center)
            Spacer()
        }.foregroundColor(BeamColor.Generic.background.swiftUI)
    }

    private func promptDeletePasswordsAlert() {
        var messageText: String = ""
        if passwordsViewModel.selectedEntries.count > 1 {
            messageText = "Are you sure you want to remove these passwords?"
        } else if let password = passwordsViewModel.selectedEntries.first {
            messageText = "Are you sure you want to remove the password for “\(password.username)” on “\(password.minimizedHost)”?"
        }

        let alert = NSAlert()
        alert.messageText = messageText
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard let window = PasswordsPreferencesViewController.view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            for entry in passwordsViewModel.selectedEntries {
                PasswordManager.shared.delete(hostname: entry.minimizedHost, for: entry.username)
            }
            passwordsViewModel.refresh()
            if !searchString.isEmpty { searchString.removeAll() }
        }
    }

    private func importPasswordAction(completion: @escaping () -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canDownloadUbiquitousContents = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["csv", "txt"]
        openPanel.title = "Select a csv file exported from Chrome, Firefox or Safari"
        openPanel.begin { result in
            guard result == .OK, let url = openPanel.url else {
                openPanel.close()
                return
            }
            do {
                try PasswordImporter.importPasswords(fromCSV: url)
                completion()
            } catch {
                Logger.shared.logError(String(describing: error), category: .general)
            }
        }
    }

    private func exportPasswordAction() {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "PasswordsExport.csv"
        savePanel.begin { (result) in
            guard result == .OK, let url = savePanel.url else {
                savePanel.close()
                return
            }
            do {
                try PasswordImporter.exportPasswords(toCSV: url)
            } catch {
                Logger.shared.logError(String(describing: error), category: .general)

            }
        }
    }
}

struct Webforms: View {
    @State var showingAdressesSheet: Bool = false
    @State var showingCreditCardsSheet: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
            Text("Autofill webforms:")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            VStack(alignment: .leading) {
                Checkbox(checkState: PreferencesManager.autofillAdresses, text: "Addresses", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                    PreferencesManager.autofillAdresses = activated
                }
                Checkbox(checkState: PreferencesManager.autofillCreditCards, text: "Credit cards", textColor: BeamColor.Generic.text.swiftUI, textFont: BeamFont.regular(size: 13).swiftUI) { activated in
                    PreferencesManager.autofillCreditCards = activated
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Button {
                    self.showingAdressesSheet.toggle()
                } label: {
                    Text("Edit...")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                .sheet(isPresented: $showingAdressesSheet) {
                    UserInformationsModalView(userInformations: MockUserInformationsStore().fetchAll())
                        .frame(width: 440, height: 361, alignment: .center)
                }
                Button {
                    self.showingCreditCardsSheet.toggle()
                } label: {
                    Text("Edit...")
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                .sheet(isPresented: $showingCreditCardsSheet) {
                    CreditCardsModalView()
                        .frame(width: 568, height: 361, alignment: .center)
                }
            }
        }.frame(width: 608, alignment: .trailing)
    }
}
