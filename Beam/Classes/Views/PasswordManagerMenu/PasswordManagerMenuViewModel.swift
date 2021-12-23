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
    func dismiss()
}

struct PasswordManagerMenuOptions: Equatable {
    let showExistingCredentials: Bool
    let suggestNewPassword: Bool

    static let login = PasswordManagerMenuOptions(showExistingCredentials: true, suggestNewPassword: false)
    static let createAccount = PasswordManagerMenuOptions(showExistingCredentials: false, suggestNewPassword: true)
    static let ambiguousPassword = PasswordManagerMenuOptions(showExistingCredentials: true, suggestNewPassword: true)
}

enum PasswordSearchCellMode {
    case none
    case button
    case field
}

class PasswordManagerMenuViewModel: ObservableObject {
    struct Contents {
        var entriesForHost: [PasswordManagerEntry]
        var allEntries: [PasswordManagerEntry]
        var hasScroll: Bool
        var hasMoreThanOneEntry: Bool
        var showSuggestPasswordOption: Bool
        var suggestNewPassword: Bool
        var userInfo: UserInformations?
    }

    weak var delegate: PasswordManagerMenuDelegate?
    var otherPasswordsViewModel: PasswordListViewModel

    @Published var passwordGeneratorViewModel: PasswordGeneratorViewModel?
    @Published var display: Contents
    @Published var scrollingListHeight: CGFloat?

    let host: URL
    let options: PasswordManagerMenuOptions
    let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let userInfoStore: UserInformationsStore
    private var entriesForHost: [PasswordManagerEntry]
    private var allEntries: [PasswordManagerEntry]
    private var revealFullList = false
    private var revealMoreItemsInList = false
    private var showPasswordGenerator = false
    private var subscribers = Set<AnyCancellable>()

    init(host: URL, credentialsBuilder: PasswordManagerCredentialsBuilder, userInfoStore: UserInformationsStore, options: PasswordManagerMenuOptions) {
        self.host = host
        self.options = options
        self.credentialsBuilder = credentialsBuilder
        self.userInfoStore = userInfoStore
        self.entriesForHost = []
        self.allEntries = []
        self.display = Contents(
            entriesForHost: Array(entriesForHost.prefix(1)),
            allEntries: allEntries,
            hasScroll: false,
            hasMoreThanOneEntry: entriesForHost.count > 1,
            showSuggestPasswordOption: options.showExistingCredentials && options.suggestNewPassword,
            suggestNewPassword: !options.showExistingCredentials,
            userInfo: userInfoStore.fetchAll().first ?? nil
        )
        self.otherPasswordsViewModel = PasswordListViewModel()
        if options.suggestNewPassword {
            let passwordGeneratorViewModel = PasswordGeneratorViewModel()
            passwordGeneratorViewModel.delegate = self
            self.passwordGeneratorViewModel = passwordGeneratorViewModel
        }
        if options.showExistingCredentials {
            let entries = PasswordManager.shared.entries(for: host.minimizedHost ?? host.urlStringWithoutScheme, exact: false)
            if !entries.isEmpty {
                self.entriesForHost = entries
                self.updateDisplay()
            }
        }
    }

    func resetItems() {
        guard revealFullList else { return }
        revertToFirstItem()
    }

    func revertToFirstItem() {
        revealFullList = false
        revealMoreItemsInList = false
        updateDisplay()
    }

    func revealMoreItemsForCurrentHost() {
        guard !revealMoreItemsInList else { return }
        revealMoreItemsInList = true
        updateDisplay()
    }

    func revealAllItems() {
        guard !revealFullList else { return }
        revealFullList = true
        updateAllEntries()
    }

    func onSuggestNewPassword(state: PasswordManagerMenuCellState) {
        guard state == .clicked else { return }
        showPasswordGenerator = true
        updateDisplay()
    }

    private func updateDisplay() {
        var visibleEntries: [PasswordManagerEntry]
        if revealMoreItemsInList {
            visibleEntries = Array(entriesForHost.prefix(3))
        } else {
            if !credentialsBuilder.hasManualInput, let bestEntry = credentialsBuilder.suggestedEntry() ?? entriesForHost.first {
                visibleEntries = [bestEntry]
            } else {
                visibleEntries = []
            }
        }
        let hasScroll = entriesForHost.count == 3
        display = Contents(
            entriesForHost: visibleEntries,
            allEntries: allEntries,
            hasScroll: hasScroll,
            hasMoreThanOneEntry: entriesForHost.count > 1,
            showSuggestPasswordOption: options.showExistingCredentials && options.suggestNewPassword && !showPasswordGenerator,
            suggestNewPassword: !options.showExistingCredentials || showPasswordGenerator,
            userInfo: display.userInfo
        )
    }

    private func updateAllEntries() {
        let entries = PasswordManager.shared.fetchAll()
        if !entries.isEmpty {
            self.allEntries = entries
            self.updateDisplay()
        }
    }

    public func getHostStr() -> String {
        var components = URLComponents()
        components.scheme = host.scheme
        components.host = host.host
        return components.url?.absoluteString ?? ""
    }
}

extension PasswordManagerMenuViewModel: PasswordManagerMenuDelegate {
    func fillCredentials(_ entry: PasswordManagerEntry) {
        Logger.shared.logDebug("Clicked on entry: \(entry.username) @ \(entry.minimizedHost)")
        delegate?.fillCredentials(entry)
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
        updateAllEntries()
    }
}

enum PasswordGeneratorOption: String, CaseIterable, CustomStringConvertible {
    case passphrase = "Passphrase"
    case password = "Password"

    var description: String { rawValue }
}

class PasswordGeneratorViewModel: ObservableObject {
    weak var delegate: PasswordManagerMenuDelegate?

    @Published var suggestion: String = ""
    @Published var generatorOption: PasswordGeneratorOption = .passphrase
    @Published var generatorPassphraseWordCount = 4
    @Published var generatorPasswordLength = 20

    private var isLocked = false
    private var subscribers = Set<AnyCancellable>()

    init() {
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
        generate()
        clicked()
    }

    func usePassword() {
        isLocked = true
        dismiss()
    }

    func dontUsePassword() {
        isLocked = false
        emptyPasswordField()
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

    private func clicked() {
        Logger.shared.logDebug("Clicked on generated password", category: .passwordManagerInternal)
        delegate?.fillNewPassword(suggestion, dismiss: false)
    }

    private func emptyPasswordField() {
        delegate?.emptyPasswordField()
    }

    private func dismiss() {
        delegate?.dismiss()
    }
}
