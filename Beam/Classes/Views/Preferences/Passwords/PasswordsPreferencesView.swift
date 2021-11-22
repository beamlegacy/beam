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
    @State private var doubleTapRow: Int = 0

    @State private var showingAddPasswordSheet: Bool = false
    @State private var showingEditPasswordSheet: Bool = false
    @State private var showingEditPasswordSheetonDoubleTap: Bool = false

    @State private var autofillUsernamePasswords = PreferencesManager.autofillUsernamePasswords

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                HStack {
                    Toggle(isOn: $autofillUsernamePasswords) {
                        Text("Autofill username and passwords")
                    }.toggleStyle(CheckboxToggleStyle())
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .foregroundColor(BeamColor.Generic.text.swiftUI)
                        .onReceive([autofillUsernamePasswords].publisher.first()) {
                            PreferencesManager.autofillUsernamePasswords = $0
                        }
                    Spacer()
                    BeamSearchField(searchStr: $searchString, isEditing: $isEditing, placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor)
                        .frame(width: 220, height: 21, alignment: .center)
                        .foregroundColor(BeamColor.Generic.background.swiftUI)
                        .onChange(of: searchString) { searchString in
                            passwordsViewModel.searchString = searchString
                        }
                }
                HStack {
                    Spacer()
                    PasswordsTableView(passwordEntries: passwordsViewModel.filteredPasswordTableViewItems) { idx in
                        passwordsViewModel.updateSelection(idx)
                    } onDoubleTap: { row in
                        doubleTapRow = row
                        showingEditPasswordSheetonDoubleTap = true
                    }
                    .frame(width: 682, height: 240, alignment: .center)
                    .border(BeamColor.Mercury.swiftUI, width: 1)
                    .background(BeamColor.Generic.background.swiftUI)
                    Spacer()

                    Button {
                    } label: {
                        Text("").hidden()
                    }.hidden()
                    .sheet(isPresented: $showingEditPasswordSheetonDoubleTap) {
                        if let password = PasswordManager.shared.password(hostname: passwordsViewModel.filteredPasswordEntries[doubleTapRow].minimizedHost, username: passwordsViewModel.filteredPasswordEntries[doubleTapRow].username) {
                            PasswordEditView(hostname: passwordsViewModel.filteredPasswordEntries[doubleTapRow].minimizedHost,
                                             username: passwordsViewModel.filteredPasswordEntries[doubleTapRow].username,
                                             password: password, editType: .update) {
                                passwordsViewModel.refresh()
                            }.frame(width: 400, height: 179, alignment: .center)
                        }
                    }
                }
                HStack {
                    Button {
                        showingAddPasswordSheet = true
                    } label: {
                        Image("basicAdd")
                            .renderingMode(.template)
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
                    }.buttonStyle(BorderedButtonStyle())
                        .disabled(passwordsViewModel.selectedEntries.count == 0)

                    Button {
                        showingEditPasswordSheet = true
                    } label: {
                        Text("Details...")
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
                        }.buttonStyle(BorderedButtonStyle())
                        Button {
                            exportPasswordAction()
                        } label: {
                            Text("Export...")
                                .font(BeamFont.regular(size: 13).swiftUI)
                        }.buttonStyle(BorderedButtonStyle())
                    }
                }
            }.frame(width: 682, alignment: .center)
            Spacer()
        }
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

    @State private var autofillAdresses = PreferencesManager.autofillAdresses
    @State private var autofillCreditCards = PreferencesManager.autofillCreditCards

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
            Text("Autofill webforms:")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            VStack(alignment: .leading) {
                Toggle(isOn: $autofillAdresses) {
                    Text("Addresses")
                }.toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onReceive([autofillAdresses].publisher.first()) {
                        PreferencesManager.autofillAdresses = $0
                    }
                Toggle(isOn: $autofillCreditCards) {
                    Text("Credit cards")
                }.toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onReceive([autofillCreditCards].publisher.first()) {
                        PreferencesManager.autofillCreditCards = $0
                    }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Button {
                    self.showingAdressesSheet.toggle()
                } label: {
                    Text("Edit...")
                        .font(BeamFont.regular(size: 13).swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                .sheet(isPresented: $showingAdressesSheet) {
                    UserInformationsModalView(userInformations: [])
                        .frame(width: 440, height: 361, alignment: .center)
                }
                Button {
                    self.showingCreditCardsSheet.toggle()
                } label: {
                    Text("Edit...")
                        .font(BeamFont.regular(size: 13).swiftUI)
                }.buttonStyle(BorderedButtonStyle())
                .sheet(isPresented: $showingCreditCardsSheet) {
                    CreditCardsModalView()
                        .frame(width: 568, height: 361, alignment: .center)
                }
            }
        }.frame(width: 608, alignment: .trailing)
    }
}
