//
//  PasswordManagerMenuViewModel.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/03/2021.
//

import Foundation
import Combine
import BeamCore

protocol PasswordManagerMenuDelegate: AnyObject {
    func fillCredentials(_ entry: PasswordManagerEntry)
    func fillNewPassword(_ password: String, dismiss: Bool)
    func deleteCredentials(_ entries: [PasswordManagerEntry])
    func emptyPasswordField()
    func dismissMenu()
    func dismiss()
}

struct PasswordManagerMenuOptions: Equatable {
    let showExistingCredentials: Bool
    let suggestNewPassword: Bool
    let showMenu: Bool

    static let login = PasswordManagerMenuOptions(showExistingCredentials: true, suggestNewPassword: false, showMenu: true)
    static let createAccount = PasswordManagerMenuOptions(showExistingCredentials: false, suggestNewPassword: true, showMenu: false)
    static let createAccountWithMenu = PasswordManagerMenuOptions(showExistingCredentials: false, suggestNewPassword: true, showMenu: true)
    static let ambiguousPassword = PasswordManagerMenuOptions(showExistingCredentials: true, suggestNewPassword: true, showMenu: true)
}

enum PasswordSearchCellMode {
    case none
    case button
    case field
}

class PasswordManagerMenuViewModel: ObservableObject {
    struct Contents {
        var entriesForHost: [PasswordManagerEntry]
        var entryDisplayLimit: Int
        var showSuggestPasswordOption: Bool
        var suggestNewPassword: Bool
        var separator1: Bool
        var separator2: Bool
        var userInfo: UserInformations?
    }

    weak var delegate: PasswordManagerMenuDelegate?
    var otherPasswordsViewModel: PasswordListViewModel

    @Published var passwordGeneratorViewModel: PasswordGeneratorViewModel?
    @Published var display: Contents
    @Published var scrollingListHeight: CGFloat?

    let host: URL
    let minimizedHost: String
    let options: PasswordManagerMenuOptions
    let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let userInfoStore: UserInformationsStore
    private var entriesForHost: [PasswordManagerEntry]
    private var revealFullList = false
    private var revealMoreItemsInList = false
    private var showPasswordGenerator = false
    private var otherPasswordsDialog: PopoverWindow?
    private var subscribers = Set<AnyCancellable>()

    init(host: URL, credentialsBuilder: PasswordManagerCredentialsBuilder, userInfoStore: UserInformationsStore, options: PasswordManagerMenuOptions) {
        self.host = host
        self.minimizedHost = host.minimizedHost ?? host.urlStringWithoutScheme
        self.options = options
        self.credentialsBuilder = credentialsBuilder
        self.userInfoStore = userInfoStore
        self.entriesForHost = []
        self.display = Contents(
            entriesForHost: entriesForHost,
            entryDisplayLimit: 0,
            showSuggestPasswordOption: false,
            suggestNewPassword: false,
            separator1: false,
            separator2: false,
            userInfo: userInfoStore.fetchAll().first ?? nil
        )
        self.otherPasswordsViewModel = PasswordListViewModel()
        if options.suggestNewPassword {
            let passwordGeneratorViewModel = PasswordGeneratorViewModel()
            passwordGeneratorViewModel.delegate = self
            self.passwordGeneratorViewModel = passwordGeneratorViewModel
        }
        self.loadEntries()
        self.updateDisplay()
    }

    func displayedHost(for entry: PasswordManagerEntry) -> String {
        entry.minimizedHost == minimizedHost ? "For this website" : entry.minimizedHost
    }

    func resetItems() {
        revertToFirstItem()
    }

    func revertToFirstItem() {
        revealMoreItemsInList = false
        updateDisplay()
    }

    func revealMoreItemsForCurrentHost() {
        guard !revealMoreItemsInList else { return }
        revealMoreItemsInList = true
        updateDisplay()
    }

    func showOtherPasswords() {
        delegate?.dismissMenu()
        guard let mainWindow = AppDelegate.main.window else { return }
        guard let childWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: false, canBecomeMain: false, withShadow: true, useBeamShadow: false, movable: true) else { return }
        otherPasswordsDialog = childWindow
        let otherPasswords = OtherPasswordsSheet(viewModel: otherPasswordsViewModel) { [weak self] entry in
            self?.closeOtherPasswordsDialog()
            self?.fillCredentials(entry)
        } onRemove: { [weak self] entry in
            self?.deleteCredentials(entry)
        } onDismiss: { [weak self] in
            self?.closeOtherPasswordsDialog()
            self?.resetItems()
        }
        let position = CGPoint(x: (mainWindow.frame.size.width - otherPasswords.width) / 2, y: (mainWindow.frame.size.height + otherPasswords.height) / 2)
        childWindow.setView(with: otherPasswords, at: position, fromTopLeft: true)
    }

    func onSuggestNewPassword(state: PasswordManagerMenuCellState) {
        guard state == .clicked else { return }
        showPasswordGenerator = true
        updateDisplay()
    }

    func close() {
        closeOtherPasswordsDialog()
    }

    private func closeOtherPasswordsDialog() {
        otherPasswordsDialog?.close()
        otherPasswordsDialog = nil
    }

    private func loadEntries() {
        if options.showExistingCredentials {
            if let bestEntry = credentialsBuilder.suggestedEntry() {
                self.entriesForHost = [bestEntry]
            } else {
                self.entriesForHost = PasswordManager.shared.entries(for: minimizedHost, options: .fuzzy)
            }
        }
    }

    private func updateDisplay() {
        let existingCredentials = options.showExistingCredentials && !entriesForHost.isEmpty
        let showOtherPasswordsOption = options.showExistingCredentials
        let showSuggestPasswordOption = options.showMenu && !showPasswordGenerator && options.suggestNewPassword
        let separator1 = existingCredentials && showOtherPasswordsOption
        let separator2 = (existingCredentials || showOtherPasswordsOption) && showSuggestPasswordOption
        let suggestNewPassword = (!options.showMenu || showPasswordGenerator) && options.suggestNewPassword
        let entryDisplayLimit = options.showExistingCredentials ? revealMoreItemsInList ? 3 : 1 : 0
        display = Contents(
            entriesForHost: entriesForHost,
            entryDisplayLimit: entryDisplayLimit,
            showSuggestPasswordOption: showSuggestPasswordOption,
            suggestNewPassword: suggestNewPassword,
            separator1: separator1,
            separator2: separator2,
            userInfo: display.userInfo
        )
    }
}

extension PasswordManagerMenuViewModel: PasswordManagerMenuDelegate {
    func fillCredentials(_ entry: PasswordManagerEntry) {
        Logger.shared.logDebug("Clicked on entry: \(entry.username) @ \(entry.minimizedHost)")
        delegate?.fillCredentials(entry)
    }

    func dismissMenu() {
        delegate?.dismissMenu()
    }

    func dismiss() {
        delegate?.dismiss()
    }

    func emptyPasswordField() {
        delegate?.emptyPasswordField()
    }

    func fillNewPassword(_ password: String, dismiss: Bool) {
        delegate?.fillNewPassword(password, dismiss: dismiss)
    }

    func deleteCredentials(_ entries: [PasswordManagerEntry]) {
        Logger.shared.logDebug("Delete \(entries.count) password manager entries")
        delegate?.deleteCredentials(entries)
        loadEntries()
    }
}

enum PasswordGeneratorOption: String, CaseIterable, CustomStringConvertible {
    case passphrase = "Passphrase"
    case password = "Password"

    var description: String { rawValue }
}

class PasswordGeneratorViewModel: NSObject, ObservableObject {
    weak var delegate: PasswordManagerMenuDelegate?

    @Published var suggestion: String = ""
    @Published var generatorOption: PasswordGeneratorOption = .passphrase
    @Published var generatorPassphraseWordCount = 4
    @Published var generatorPasswordLength = 20

    private var isLocked = false
    private var isDismissed = false
    private var hasPendingSuggestion = false
    private var subscribers = Set<AnyCancellable>()

    override init() {
        super.init()
        $generatorOption.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: newValue, generatorPassphraseWordCount: self.generatorPassphraseWordCount, generatorPasswordLength: self.generatorPasswordLength)
        }).store(in: &subscribers)
        $generatorPassphraseWordCount.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: self.generatorOption, generatorPassphraseWordCount: newValue, generatorPasswordLength: self.generatorPasswordLength)
        }).store(in: &subscribers)
        $generatorPasswordLength.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: self.generatorOption, generatorPassphraseWordCount: self.generatorPassphraseWordCount, generatorPasswordLength: newValue)
        }).store(in: &subscribers)
    }

    func start() {
        guard !isLocked else { return }
        isDismissed = false
        generate()
        delegate?.fillNewPassword(suggestion, dismiss: false)
        hasPendingSuggestion = true
    }

    func usePassword() {
        isLocked = true
        hasPendingSuggestion = false
        dismiss()
    }

    func dontUsePassword() {
        isLocked = false
        emptyPasswordField()
        hasPendingSuggestion = false
    }

    private func generate() {
        isLocked = false
        generate(generatorOption: generatorOption, generatorPassphraseWordCount: generatorPassphraseWordCount, generatorPasswordLength: generatorPasswordLength)
    }

    private func generate(generatorOption: PasswordGeneratorOption, generatorPassphraseWordCount: Int, generatorPasswordLength: Int) {
        switch generatorOption {
        case .passphrase:
            suggestion = PasswordGenerator.shared.generatePassphrase(wordCount: generatorPassphraseWordCount)
        case .password:
            suggestion = PasswordGenerator.shared.generatePassword(length: generatorPasswordLength)
        }
    }

    private func emptyPasswordField() {
        delegate?.emptyPasswordField()
    }

    private func dismiss() {
        isDismissed = true
        delegate?.dismiss()
    }
}

extension PasswordGeneratorViewModel: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if !isDismissed && hasPendingSuggestion {
            dontUsePassword()
        }
    }
}
