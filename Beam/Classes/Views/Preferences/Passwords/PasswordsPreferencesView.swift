//
//  PasswordsPreferencesView.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/06/2021.
//

import SwiftUI
import BeamCore

struct PasswordsPreferencesView: View {
    var passwordsViewModel: PasswordListViewModel
    var creditCardsViewModel: CreditCardListViewModel

    @Environment(\.controlActiveState) var controlActiveState

    @State private var isUnlocked: Bool = false

    private func checkAuthentication() {
        Task { @MainActor in
            await passwordsViewModel.checkAuthentication()
            isUnlocked = passwordsViewModel.isUnlocked
        }
    }

    private func lock() {
        isUnlocked = false
    }

    var body: some View {
        Settings.Container(contentWidth: PreferencesManager.contentWidth) {
            Settings.Row(hasDivider: isUnlocked) {
            } content: {
                let isUnlocked = isUnlocked
                VStack {
                    Passwords(passwordsViewModel: passwordsViewModel)
                        .if(!isUnlocked) {
                            $0.opacity(0)
                            .overlay(LockedPasswordsView(onUnlockPressed: { checkAuthentication() }),
                                     alignment: .center)
                        }
                }
                .onChange(of: controlActiveState) { newState in
                    guard newState == .inactive && AppDelegate.main.settingsWindowController.window?.isVisible == false else { return }
                    lock()
                }
                .onAppear {
                    guard !self.isUnlocked else { return }
                    checkAuthentication()
                }
                .onDisappear {
                    lock()
                }
            }
            Settings.Row {
            } content: {
                Webforms(creditCardsViewModel: creditCardsViewModel)
                    .opacity(isUnlocked ? 1 : 0)
            }
        }
    }
}

struct PasswordsPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordsPreferencesView(passwordsViewModel: PasswordListViewModel(passwordManager: PasswordManager(objectManager: BeamObjectManager()), showNeverSavedEntries: true), creditCardsViewModel: CreditCardListViewModel())
    }
}

private struct LockedPasswordsView: View {

    @State private var hasTouchID: Bool = false
    var onUnlockPressed: () -> Void
    private func updateHasTouchID() {
        hasTouchID = DeviceAuthenticationManager.shared.deviceHasTouchID()
    }

    private var unlockSubtitle: String {
        let username = NSFullUserName()
        var text = loc("Click the Unlock button to ")
        if hasTouchID {
            text += loc("Touch ID or ")
        }
        text += loc("enter the password for the user “\(username)”")
        return text
    }

    var body: some View {
        VStack(alignment: .center, spacing: BeamSpacing._200) {
            Image("preferences-passswords_lock")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            VStack(alignment: .center, spacing: BeamSpacing._100) {
                Text(loc("Passwords Are Locked"))
                    .font(BeamFont.semibold(size: 18).swiftUI)
                Text(unlockSubtitle)
                    .multilineTextAlignment(.center)
                    .font(BeamFont.regular(size: 13).swiftUI)
            }
            .frame(maxWidth: 340)
            Button(action: {
                onUnlockPressed()
            }, label: {
                Text(loc("Unlock"))
                    .frame(minWidth: 100)
            })
        }
        .foregroundColor(BeamColor.Generic.text.swiftUI)
        .onAppear {
            updateHasTouchID()
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                // sometimes touch ID isn't available right away
                updateHasTouchID()
            }
        }
    }
}

struct Passwords: View {
    @ObservedObject var passwordsViewModel: PasswordListViewModel

    @State private var searchString = ""
    @State private var isEditing = false

    @State private var showingAddPasswordSheet = false
    @State private var editedPassword: PasswordListViewModel.EditedPassword?
    @State private var alertMessage: PasswordListViewModel.AlertMessage?

    @State private var localPrivateKeyAlertMessage: IdentifiableString?

    @State private var autofillUsernamePasswords = PreferencesManager.autofillUsernamePasswords

    @State private var availableImportSources: [OnboardingImportsView.ImportSource] = [.passwordsCSV]

    private var topRow: some View {
        HStack {
            Toggle(isOn: $autofillUsernamePasswords) {
                Text("Autofill usernames and passwords")
            }.toggleStyle(CheckboxToggleStyle())
                .font(BeamFont.regular(size: 13).swiftUI)
                .foregroundColor(BeamColor.Generic.text.swiftUI)
                .onChange(of: autofillUsernamePasswords, perform: {
                    PreferencesManager.autofillUsernamePasswords = $0
                })
            Spacer()
            BeamSearchField(searchStr: $searchString, isEditing: $isEditing, placeholderStr: "Search", font: BeamFont.regular(size: 13).nsFont, textColor: BeamColor.Generic.text.nsColor, placeholderColor: BeamColor.Generic.placeholder.nsColor)
                .frame(width: 220, height: 21, alignment: .center)
                .foregroundColor(BeamColor.Generic.tableViewBackground.swiftUI)
                .onChange(of: searchString) { searchString in
                    passwordsViewModel.searchString = searchString
                }
        }
    }

    private var passwordTableView: some View {
        HStack {
            PasswordsTableView(passwordEntries: passwordsViewModel.filteredPasswordTableViewItems) { idx in
                passwordsViewModel.updateSelection(idx)
            } onDoubleTap: { row in
                let entry = passwordsViewModel.filteredPasswordEntries[row]
                guard !entry.neverSaved else { return }
                do {
                    let password = try passwordsViewModel.passwordManager.password(hostname: entry.minimizedHost, username: entry.username, markUsed: false)
                    editedPassword = PasswordListViewModel.EditedPassword(entry: entry, password: password)
                } catch {
                    alertMessage = .init(error: error)
                }
            }
            .frame(width: 682, height: 240, alignment: .center)
            .border(BeamColor.Generic.tableViewStroke.swiftUI, width: 1)
            .background(BeamColor.Generic.tableViewBackground.swiftUI)
        }
    }

    private var bottomRow: some View {
        HStack {
            BeamControlGroup(accessibilityIdentifier: "addRemovePassword") {
                HStack {
                    Button {
                        showingAddPasswordSheet = true
                    } label: {
                        Image("basicAdd")
                            .renderingMode(.template)
                    }.buttonStyle(.bordered)
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
            .sheet(isPresented: $showingAddPasswordSheet) {
                PasswordEditView(entry: nil, password: "", editType: .create)
                    .frame(width: 400, height: 179, alignment: .center)
            }
            Button {
                if let entry = passwordsViewModel.selectedEntries.first {
                    do {
                        let password = try passwordsViewModel.passwordManager.password(hostname: entry.minimizedHost, username: entry.username, markUsed: false)
                        editedPassword = PasswordListViewModel.EditedPassword(entry: entry, password: password)
                    } catch {
                        alertMessage = .init(error: error)
                    }
                }
            } label: {
                Text("Details…")
            }.buttonStyle(.bordered)
                .keyboardShortcut(.defaultAction)
                .sheet(item: $editedPassword) {
                    PasswordEditView(entry: $0.entry, password: $0.password, editType: .update)
                }
                .disabled(passwordsViewModel.selectedEntries.count == 0 || passwordsViewModel.selectedEntries.count > 1 || passwordsViewModel.selectedEntries[0].neverSaved)
            Spacer()
            HStack {
                Menu("Import…") {
                    ForEach(availableImportSources, id: \.self) { importSource in
                        Button(importSource.rawValue) {
                            importPasswordsAction(source: importSource)
                        }
                    }
                }
                .font(BeamFont.regular(size: 13).swiftUI)
                .frame(width: 96)
                Button {
                    exportPasswordAction()
                } label: {
                    Text("Export…")
                        .font(BeamFont.regular(size: 13).swiftUI)
                }.buttonStyle(.bordered)
            }
        }
    }

    private func localEncryptionKeyRow(_ privateKeyCheck: PasswordListViewModel.LocalPrivateKeyResult) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Some passwords can't be decrypted.")
            Button {
                localPrivateKeyAlertMessage = IdentifiableString(privateKeyCheck.alertMessage)
            } label: {
                Text("More Information…")
            }
            Spacer()
        }
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .center) {
                topRow
                passwordTableView
                bottomRow
                if let privateKeyCheck = passwordsViewModel.localPrivateKeyCheck, !privateKeyCheck.isValid {
                    localEncryptionKeyRow(privateKeyCheck)
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
        .alert(item: $localPrivateKeyAlertMessage) {
            Alert(
                title: Text("Some passwords could not be decrypted."),
                message: Text($0.string),
                primaryButton: .default(Text("Delete unrecoverable passwords")) {
                    deleteUnrecoverablePasswords()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func updateAvailableSources() {
        availableImportSources = OnboardingImportsView.ImportSource.allCases
            .filter { $0 == .passwordsCSV || $0.supportsAutomaticPasswordImport }
            .filter { $0.isAvailable }
    }

    private func deleteUnrecoverablePasswords() {
        try? passwordsViewModel.passwordManager.deleteUnrecoverablePasswords()
        passwordsViewModel.checkLocalPrivateKey()
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
        guard let window = AppDelegate.main.settingsWindowController.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            for entry in passwordsViewModel.selectedEntries {
                passwordsViewModel.passwordManager.markDeleted(hostname: entry.minimizedHost, for: entry.username)
            }
            if passwordsViewModel.filteredPasswordEntries.count == passwordsViewModel.selectedEntries.count && !searchString.isEmpty {
                searchString.removeAll()
            }
        }
    }

    private func importPasswordsAction(source: OnboardingImportsView.ImportSource) {
        let importsManager = BeamData.shared.importsManager
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
        savePanel.allowedContentTypes = [BeamUniformTypeIdentifiers.passwordsExportType]
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

    // @State private var showingAdressesSheet: Bool = false
    @State private var showingCreditCardsSheet: Bool = false

    // @State private var autofillAdresses = PreferencesManager.autofillAdresses
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
                    .onChange(of: autofillCreditCards, perform: {
                        PreferencesManager.autofillCreditCards = $0
                    })
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
