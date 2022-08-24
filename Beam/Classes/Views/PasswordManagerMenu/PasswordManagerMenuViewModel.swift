//
//  PasswordManagerMenuViewModel.swift
//  Beam
//
//  Created by Frank Lefebvre on 31/03/2021.
//

import Foundation
import Combine
import BeamCore

protocol PasswordManagerMenuDelegate: WebAutofillMenuDelegate {
    func fillCredentials(_ entry: PasswordManagerEntry)
    func fillNewPassword(_ password: String, dismiss: Bool)
    func deleteCredentials(_ entries: [PasswordManagerEntry])
    func emptyPasswordField()
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

class PasswordManagerMenuViewModel: ObservableObject {
    enum MenuItem: Equatable, Identifiable {
        case autofillEntry(PasswordManagerEntry)
        case showMoreEntriesForHost(String)
        case showAllPasswords
        case showSuggestPassword
        case suggestNewPassword(PasswordGeneratorViewModel) // not used anymore?
        case separator(Int)

        var id: String {
            switch self {
            case .autofillEntry(let entry):
                return "autofill \(entry.minimizedHost) \(entry.username)"
            case .showMoreEntriesForHost(let host):
                return "showmore \(host)"
            case .showAllPasswords:
                return "showall"
            case .showSuggestPassword:
                return "showsuggest"
            case .suggestNewPassword:
                return "suggest"
            case .separator(let identifier):
                return "separator \(identifier)"
            }
        }

        var isSelectable: Bool {
            switch self {
            case .separator, .suggestNewPassword:
                return false
            default:
                return true
            }
        }

        func performAction(with viewModel: PasswordManagerMenuViewModel) {
            switch self {
            case .autofillEntry(let entry):
                viewModel.fillCredentials(entry)
            case .showMoreEntriesForHost:
                viewModel.revealMoreItemsForCurrentHost()
            case .showAllPasswords:
                viewModel.showOtherPasswords()
            case .suggestNewPassword:
                viewModel.onSuggestNewPassword(state: WebFieldAutofillMenuCellState.clicked)
            default:
                break
            }
        }
    }

    weak var delegate: PasswordManagerMenuDelegate?
    var otherPasswordsViewModel: PasswordListViewModel

    @Published var passwordGeneratorViewModel: PasswordGeneratorViewModel?
    @Published var suggestNewPassword = false
    @Published var autofillMenuItems: [MenuItem]
    @Published var otherMenuItems: [MenuItem]
    @Published var scrollingListHeight: CGFloat?

    let host: URL
    let minimizedHost: String
    let options: PasswordManagerMenuOptions
    let credentialsBuilder: PasswordManagerCredentialsBuilder
    private let userInfoStore: UserInformationsStore
    private var entriesForHost: [PasswordManagerEntry]
    private let selectionHandler = WebAutofillMenuSelectionHandler()
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
        self.autofillMenuItems = []
        self.otherMenuItems = []
        self.otherPasswordsViewModel = PasswordListViewModel()
        if options.suggestNewPassword {
            let passwordGeneratorViewModel = PasswordGeneratorViewModel()
            passwordGeneratorViewModel.delegate = self
            self.passwordGeneratorViewModel = passwordGeneratorViewModel
        }
        self.loadEntries()
        self.updateDisplay()
    }

    func handleStateChange(itemId: String, newState: WebFieldAutofillMenuCellState) {
        if selectionHandler.handleStateChange(itemId: itemId, newState: newState) {
            objectWillChange.send()
        }
    }

    func highlightState(of itemId: String) -> Bool {
        selectionHandler.highlightState(of: itemId)
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
        guard let childWindow = CustomPopoverPresenter.shared.presentPopoverChildWindow(canBecomeKey: true, canBecomeMain: false, withShadow: true, useBeamShadow: false, movable: true, autocloseIfNotMoved: false) else { return }
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
        childWindow.makeKeyAndOrderFront(nil)
    }

    func onSuggestNewPassword(state: WebFieldAutofillMenuCellState) {
        guard state == .clicked else { return }
        showPasswordGenerator = true
        updateDisplay()
    }

    func close() {
        closeOtherPasswordsDialog()
    }

    var isPresentingModalDialog: Bool {
        otherPasswordsDialog != nil
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
        let showOtherPasswordsOption = options.showExistingCredentials
        let showSuggestPasswordOption = options.showMenu && !showPasswordGenerator && options.suggestNewPassword
        suggestNewPassword = (!options.showMenu || showPasswordGenerator) && options.suggestNewPassword
        let entryDisplayLimit = options.showExistingCredentials ? revealMoreItemsInList ? 3 : 1 : 0
        if suggestNewPassword, let passwordGeneratorViewModel = passwordGeneratorViewModel {
            autofillMenuItems = []
            otherMenuItems = [.suggestNewPassword(passwordGeneratorViewModel)]
        } else {
            autofillMenuItems = entriesForHost.prefix(entryDisplayLimit).map { MenuItem.autofillEntry($0) }
            var menuItems = [MenuItem]()
            if showOtherPasswordsOption {
                if !autofillMenuItems.isEmpty {
                    menuItems.append(.separator(1))
                }
                if entriesForHost.count <= entryDisplayLimit || revealMoreItemsInList {
                    menuItems.append(.showAllPasswords)
                } else {
                    menuItems.append(.showMoreEntriesForHost(minimizedHost))
                }
            }
            if showSuggestPasswordOption {
                if !autofillMenuItems.isEmpty || !menuItems.isEmpty {
                    menuItems.append(.separator(2))
                }
                menuItems.append(.showSuggestPassword)
            }
            otherMenuItems = menuItems
        }
        selectionHandler.update(selectableIds: (autofillMenuItems + otherMenuItems).filter(\.isSelectable).map(\.id))
    }
}

extension PasswordManagerMenuViewModel: PasswordManagerMenuDelegate {
    func fillCredentials(_ entry: PasswordManagerEntry) {
        Logger.shared.logDebug("Clicked on entry: \(entry.username) @ \(entry.minimizedHost)")
        Task { @MainActor in
            delegate?.fillCredentials(entry)
        }
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

extension PasswordManagerMenuViewModel: KeyEventHijacking {
    func onKeyDown(with event: NSEvent) -> Bool {
        switch selectionHandler.onKeyDown(with: event) {
        case .none:
            break
        case .refresh:
            objectWillChange.send()
        case .select(let itemId):
            if let menuItem = (autofillMenuItems + otherMenuItems).first(where: { $0.id == itemId }) {
                menuItem.performAction(with: self)
            }
        }
        return true
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
    @Published var generatorOption: PasswordGeneratorOption = .password
    @Published var generatorPassphraseWordCount = 4
    @Published var generatorPasswordBlockCount = 3

    private var isLocked = false
    private var isDismissed = false
    private var hasPendingSuggestion = false
    private var subscribers = Set<AnyCancellable>()

    override init() {
        super.init()
        $generatorOption.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: newValue, generatorPassphraseWordCount: self.generatorPassphraseWordCount, generatorPasswordBlockCount: self.generatorPasswordBlockCount)
        }).store(in: &subscribers)
        $generatorPassphraseWordCount.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: self.generatorOption, generatorPassphraseWordCount: newValue, generatorPasswordBlockCount: self.generatorPasswordBlockCount)
        }).store(in: &subscribers)
        $generatorPasswordBlockCount.sink(receiveValue: { [weak self] newValue in
            guard let self = self else { return }
            self.generate(generatorOption: self.generatorOption, generatorPassphraseWordCount: self.generatorPassphraseWordCount, generatorPasswordBlockCount: newValue)
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
        generate(generatorOption: generatorOption, generatorPassphraseWordCount: generatorPassphraseWordCount, generatorPasswordBlockCount: generatorPasswordBlockCount)
    }

    private func generate(generatorOption: PasswordGeneratorOption, generatorPassphraseWordCount: Int, generatorPasswordBlockCount: Int) {
        switch generatorOption {
        case .passphrase:
            suggestion = PasswordGenerator.shared.generatePassphrase(wordCount: generatorPassphraseWordCount)
        case .password:
            suggestion = PasswordGenerator.shared.generatePassword(blockCount: generatorPasswordBlockCount)
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
            isDismissed = true
            dontUsePassword()
        }
    }
}
