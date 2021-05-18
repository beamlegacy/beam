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
    func emptyPasswordField()
    func dismiss()
}

enum PasswordSearchCellMode {
    case none
    case button
    case field
}

class PasswordManagerMenuViewModel: ObservableObject {
    struct Contents {
        var entries: [PasswordManagerEntry]
        var hasScroll: Bool
        var hasMoreThanOneEntry: Bool
        var userInfo: UserInformations
    }

    weak var delegate: PasswordManagerMenuDelegate?

    @Published var passwordGeneratorViewModel: PasswordGeneratorViewModel?
    @Published var display: Contents
    @Published var scrollingListHeight: CGFloat?

    private let host: URL
    private let passwordStore: PasswordStore
    private let userInfoStore: UserInformationsStore
    private var entries: [PasswordManagerEntry]
    private var searchCellVisibility: PasswordSearchCellMode = .button
    private var revealFullList: Bool = false
    private var revealMoreItemsInList: Bool = false
    private var subscribers = Set<AnyCancellable>()
    private var showGeneratorPreferences = false

    init(host: URL, passwordStore: PasswordStore, userInfoStore: UserInformationsStore, withPasswordGenerator passwordGenerator: Bool) {
        self.host = host
        self.passwordStore = passwordStore
        self.userInfoStore = userInfoStore
        self.entries = []
        self.display = Contents(entries: Array(entries.prefix(1)), hasScroll: false, hasMoreThanOneEntry: entries.count > 1, userInfo: userInfoStore.get())
        if passwordGenerator {
            let passwordGeneratorViewModel = PasswordGeneratorViewModel()
            passwordGeneratorViewModel.delegate = self
            passwordGeneratorViewModel.$showPreferences.sink(receiveValue: { (showPreferences) in
                self.showGeneratorPreferences = showPreferences
                self.updateDisplay()
            }).store(in: &self.subscribers)
            self.passwordGeneratorViewModel = passwordGeneratorViewModel
        } else {
            self.passwordStore.entries(for: host) {
                self.entries = $0
                self.updateDisplay()
            }
        }
    }

    func resetItems() {
        guard revealFullList else { return }
        revealFullList = false
        revealMoreItemsInList = false
        updateDisplay()
    }

    func revealMoreItems() {
        guard !revealMoreItemsInList else { return }
        revealMoreItemsInList = true
        updateDisplay()
    }

    func revealAllItems() {
        guard !revealFullList else { return }
        revealMoreItemsInList = false
        revealFullList = true
        updateDisplay()
    }

    func startSearch() {
        entries = []
        searchCellVisibility = .field
        revealFullList = false
        updateDisplay()
    }

    func updateSearchString(_ searchString: String) {
        guard !searchString.isEmpty else { return }
        passwordStore.find(searchString) {
            self.entries = $0
            self.updateDisplay()
        }
    }

    func fillCredentials(_ entry: PasswordManagerEntry) {
        Logger.shared.logDebug("Clicked on entry: \(entry.username) @ \(entry.host)")
        delegate?.fillCredentials(entry)
    }

    func removeCredentials(_ entry: PasswordManagerEntry) {
    }

    private func updateDisplay() {
        var visibleEntries = revealFullList ? entries : Array(entries.prefix(1))
        visibleEntries = revealMoreItemsInList ? Array(entries.prefix(3)) : visibleEntries
        let hasScroll = entries.count == 3
        display = Contents(entries: visibleEntries, hasScroll: hasScroll, hasMoreThanOneEntry: entries.count > 1, userInfo: display.userInfo)
    }

    public func getHostStr() -> String {
        var components = URLComponents()
        components.scheme = host.scheme
        components.host = host.host
        return components.url?.absoluteString ?? ""
    }
}

extension PasswordManagerMenuViewModel: PasswordManagerMenuDelegate {
    func dismiss() {
        delegate?.dismiss()
    }

    func emptyPasswordField() {
        delegate?.emptyPasswordField()
    }

    func fillNewPassword(_ password: String, dismiss: Bool) {
        delegate?.fillNewPassword(password, dismiss: dismiss)
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
    @Published var showPreferences = false
    @Published var generatorOption: PasswordGeneratorOption = .passphrase
    @Published var generatorPassphraseWordCount = 4
    @Published var generatorPasswordLength = 20

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

    func generate() {
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

    func togglePreferences() {
        showPreferences.toggle()
    }

    func clicked() {
        Logger.shared.logDebug("Clicked on generated password: \(suggestion)")
        delegate?.fillNewPassword(suggestion, dismiss: false)
    }

    func emptyPasswordField() {
        delegate?.emptyPasswordField()
    }

    func dismiss() {
        delegate?.dismiss()
    }
}
