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
    PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel(), creditCardsViewModel: CreditCardListViewModel())
}

struct PasswordsPreferencesView: View {
    private let contentWidth: Double = PreferencesManager.contentWidth
    var passwordsViewModel: PasswordListViewModel
    var creditCardsViewModel: CreditCardListViewModel

    var body: some View {
        Preferences.Container(contentWidth: contentWidth) {
            Preferences.Section(bottomDivider: true) {
                Text("").labelsHidden()
            } content: {
                VStack {
                    Passwords(passwordsViewModel: passwordsViewModel)
                }
            }
            Preferences.Section {
                Text("").labelsHidden()
            } content: {
                Webforms(creditCardsViewModel: creditCardsViewModel)
            }
        }
    }
}

struct PasswordsPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel(), creditCardsViewModel: CreditCardListViewModel())
    }
}

struct Passwords: View {
    @ObservedObject var passwordsViewModel: PasswordListViewModel

    @State var searchString = ""
    @State var isEditing = false

    @State private var selectedEntries = IndexSet()
    @State private var passwordSelected = false
    @State private var multipleSelection = false

    @State private var showingAddPasswordSheet = false
    @State private var editedPassword: PasswordListViewModel.EditedPassword?
    @State private var alertMessage: PasswordListViewModel.AlertMessage?

    @State private var autofillUsernamePasswords = PreferencesManager.autofillUsernamePasswords

    @State private var availableImportSources: [OnboardingImportsView.ImportSource] = [.passwordsCSV]
    @State private var importPasswordsChoice = -1

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                HStack {
                    Toggle(isOn: $autofillUsernamePasswords) {
                        Text("Autofill usernames and passwords")
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
                        let entry = passwordsViewModel.filteredPasswordEntries[row]
                        do {
                            let password = try PasswordManager.shared.password(hostname: entry.minimizedHost, username: entry.username)
                            editedPassword = PasswordListViewModel.EditedPassword(entry: entry, password: password)
                        } catch {
                            alertMessage = .init(error: error)
                        }
                    }
                    .frame(width: 682, height: 240, alignment: .center)
                    .border(BeamColor.Mercury.swiftUI, width: 1)
                    .background(BeamColor.Generic.background.swiftUI)
                    Spacer()
                }
                HStack {
                    Group {
                        Group {
                            Button {
                                showingAddPasswordSheet = true
                            } label: {
                                Image("basicAdd")
                                    .renderingMode(.template)
                            }.buttonStyle(.bordered)
                                .sheet(isPresented: $showingAddPasswordSheet) {
                                    PasswordEditView(entry: nil, password: "", editType: .create)
                                        .frame(width: 400, height: 179, alignment: .center)
                                }
                            Button {
                                promptDeletePasswordsAlert()
                            } label: {
                                Image("basicRemove")
                                    .renderingMode(.template)
                            }.buttonStyle(.bordered)
                                .disabled(passwordsViewModel.selectedEntries.count == 0)
                        }
                    }
                    .fixedSize()

                    Button {
                        if let entry = passwordsViewModel.selectedEntries.first {
                            do {
                                let password = try PasswordManager.shared.password(hostname: entry.minimizedHost, username: entry.username)
                                editedPassword = PasswordListViewModel.EditedPassword(entry: entry, password: password)
                            } catch {
                                alertMessage = .init(error: error)
                            }
                        }
                    } label: {
                        Text("Details…")
                    }.buttonStyle(.bordered)
                        .sheet(item: $editedPassword) {
                            PasswordEditView(entry: $0.entry, password: $0.password, editType: .update)
                        }
                        .disabled(passwordsViewModel.selectedEntries.count == 0 || passwordsViewModel.selectedEntries.count > 1)
                    Spacer()
                    HStack {
                        Picker("", selection: $importPasswordsChoice) {
                            Text("Import…").tag(-1)
                            ForEach(Array(availableImportSources.enumerated()), id: \.self.0) { (idx, src) in
                                Text(src.rawValue).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(BeamFont.regular(size: 13).swiftUI)
                        .frame(width: 96)
                        .onChange(of: importPasswordsChoice) { index in
                            if index >= 0 {
                                let importSource = availableImportSources[index]
                                importPasswordsChoice = -1
                                importPasswordsAction(source: importSource)
                            }
                        }
                        Button {
                            exportPasswordAction()
                        } label: {
                            Text("Export…")
                                .font(BeamFont.regular(size: 13).swiftUI)
                        }.buttonStyle(.bordered)
                    }
                }
            }.frame(width: 682, alignment: .center)
            Spacer()
        }
        .onAppear {
            updateAvailableSources()
        }
        .alert(item: $alertMessage) {
            Alert(title: Text($0.message))
        }
    }

    private func updateAvailableSources() {
        availableImportSources = OnboardingImportsView.ImportSource.allCases
            .filter { $0 == .passwordsCSV || $0.supportsAutomaticPasswordImport }
            .filter { $0.isAvailable }
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
                PasswordManager.shared.markDeleted(hostname: entry.minimizedHost, for: entry.username)
            }
            if !searchString.isEmpty { searchString.removeAll() }
        }
    }

    private func importPasswordsAction(source: OnboardingImportsView.ImportSource) {
        let importsManager = AppDelegate.main.data.importsManager
        if source.supportsAutomaticPasswordImport, let passwordImporter = source.passwordImporter {
            importsManager.startBrowserPasswordImport(from: passwordImporter)
        } else {
            chooseCSVFile { url in
                guard let url = url else { return }
                importsManager.startBrowserPasswordImport(from: url)
            }
        }
    }

    private func chooseCSVFile(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canDownloadUbiquitousContents = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["csv", "txt"]
        openPanel.message = "Select a csv file exported from Beam, Chrome, Firefox or Safari"
        openPanel.begin { result in
            let url = result == .OK ? openPanel.url : nil
            openPanel.close()
            completion(url)
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
                try PasswordImporter.exportPasswords(toCSV: url) { exportResult in
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Password export done."
                        if exportResult.failedEntries.isEmpty {
                            alert.informativeText = "\(exportResult.exportedItems) passwords were successfully exported."
                        } else {
                            alert.informativeText = "\(exportResult.exportedItems) passwords were successfully exported.\n\(exportResult.failedEntries.count) items could not be exported."
                        }
                        alert.runModal()
                    }
                }
            } catch {
                Logger.shared.logError(String(describing: error), category: .general)

            }
        }
    }
}

struct Webforms: View {
    var creditCardsViewModel: CreditCardListViewModel

    @State private var showingAdressesSheet: Bool = false
    @State private var showingCreditCardsSheet: Bool = false

    @State private var autofillAdresses = PreferencesManager.autofillAdresses
    @State private var autofillCreditCards = PreferencesManager.autofillCreditCards

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Spacer()
            Text("Autofill webforms:")
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
            VStack {
                /* Uncomment when personal information autofill is implemented.
                HStack(alignment: .firstTextBaseline) {
                    Toggle(isOn: $autofillAdresses) {
                        Text("Addresses")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onReceive([autofillAdresses].publisher.first()) {
                        PreferencesManager.autofillAdresses = $0
                    }
                    Spacer()
                    Button {
                        self.showingAdressesSheet.toggle()
                    } label: {
                        Text("Edit...")
                            .font(BeamFont.regular(size: 13).swiftUI)
                    }
                    .buttonStyle(.bordered)
                    .offset(y: 6)
                    .sheet(isPresented: $showingAdressesSheet) {
                        UserInformationsModalView(userInformations: [])
                            .frame(width: 440, height: 361, alignment: .center)
                    }
                }
                */
                HStack(alignment: .firstTextBaseline) {
                    Toggle(isOn: $autofillCreditCards) {
                        Text("Credit cards")
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .font(BeamFont.regular(size: 13).swiftUI)
                    .foregroundColor(BeamColor.Generic.text.swiftUI)
                    .onReceive([autofillCreditCards].publisher.first()) {
                        PreferencesManager.autofillCreditCards = $0
                    }
                    Spacer()
                    Button {
                        self.showingCreditCardsSheet.toggle()
                    } label: {
                        Text("Edit...")
                            .font(BeamFont.regular(size: 13).swiftUI)
                    }
                    .buttonStyle(.bordered)
                    .offset(y: 6)
                    .sheet(isPresented: $showingCreditCardsSheet) {
                        CreditCardsModalView(creditCardsViewModel: self.creditCardsViewModel)
                            .frame(width: 568, height: 361, alignment: .center)
                    }
                }
            }
            .frame(maxWidth: 400)
        }
        .frame(width: 608)
    }
}
