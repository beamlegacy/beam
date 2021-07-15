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
    func deleteCredentials(_ entry: PasswordManagerEntry)
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
        var entriesForHost: [PasswordManagerEntry]
        var allEntries: [PasswordManagerEntry]
        var hasScroll: Bool
        var hasMoreThanOneEntry: Bool
        var userInfo: UserInformations?
    }

    weak var delegate: PasswordManagerMenuDelegate?

    @Published var passwordGeneratorViewModel: PasswordGeneratorViewModel?
    @Published var display: Contents
    @Published var scrollingListHeight: CGFloat?

    private let host: URL
    private let passwordStore: PasswordStore
    private let userInfoStore: UserInformationsStore
    private var entriesForHost: [PasswordManagerEntry]
    private var allEntries: [PasswordManagerEntry]
    private var revealFullList: Bool = false
    private var revealMoreItemsInList: Bool = false
    private var subscribers = Set<AnyCancellable>()

    init(host: URL, passwordStore: PasswordStore, userInfoStore: UserInformationsStore, withPasswordGenerator passwordGenerator: Bool) {
        self.host = host
        self.passwordStore = passwordStore
        self.userInfoStore = userInfoStore
        self.entriesForHost = []
        self.allEntries = []
        self.display = Contents(entriesForHost: Array(entriesForHost.prefix(1)), allEntries: allEntries, hasScroll: false, hasMoreThanOneEntry: entriesForHost.count > 1, userInfo: userInfoStore.fetchAll().first ?? nil)
        if passwordGenerator {
            let passwordGeneratorViewModel = PasswordGeneratorViewModel()
            passwordGeneratorViewModel.delegate = self
            self.passwordGeneratorViewModel = passwordGeneratorViewModel
        } else {
            self.passwordStore.entries(for: host.minimizedHost ?? host.urlStringWithoutScheme) {
                self.entriesForHost = $0
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

    private func updateDisplay() {
        var visibleEntries = Array(entriesForHost.prefix(1))
        visibleEntries = revealMoreItemsInList ? Array(entriesForHost.prefix(3)) : visibleEntries
        let hasScroll = entriesForHost.count == 3
        display = Contents(entriesForHost: visibleEntries, allEntries: allEntries, hasScroll: hasScroll, hasMoreThanOneEntry: entriesForHost.count > 1, userInfo: display.userInfo)
    }

    private func updateAllEntries() {
        self.passwordStore.fetchAll(completion: { allEntries in
            self.allEntries = allEntries
            self.updateDisplay()
        })
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

    func deleteCredentials(_ entry: PasswordManagerEntry) {
        Logger.shared.logDebug("Delete entry: \(entry.username) @ \(entry.minimizedHost)")
        delegate?.deleteCredentials(entry)
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
