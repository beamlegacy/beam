//
//  PasswordManagerCredentialsBuilder.swift
//  Beam
//
//  Created by Beam on 15/09/2021.
//

import Foundation
import BeamCore

final class PasswordManagerCredentialsBuilder {
    struct StoredCredentials {
        var username: String?
        var password: String
        var askSaveConfirmation: Bool
    }

    private enum FieldContents {
        case none
        case initial(String)
        case autofilled(String)
        case userInput(String)
        case generated(String)

        var value: String? {
            switch self {
            case .none:
                return nil
            case .initial(let value), .autofilled(let value), .userInput(let value), .generated(let value):
                return value
            }
        }

        var isAutofilled: Bool {
            switch self {
            case .autofilled:
                return true
            default:
                return false
            }
        }
    }

    private var passwordManager: PasswordManager
    private var currentHost: String? // actual minimized host (from current page)
    private var autofilledHost: String? // minimized host from selected credentials, needed to fetch password
    private var usernameField: FieldContents = .none
    private var passwordField: FieldContents = .none
    private var isDirty = false

    init(passwordManager: PasswordManager = .shared) {
        self.passwordManager = passwordManager
    }

    func enterPage(url: URL?) {
        let newHost = url?.minimizedHost
        if newHost != currentHost {
            reset()
            currentHost = newHost
        }
    }

    func autofill(host: String, username: String, password: String) {
        autofilledHost = host == currentHost ? nil : host
        isDirty = false
        Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Storing autofill for \(host) (current: \(currentHost ?? "nil")): dirty = \(isDirty)", category: .passwordManagerInternal)
        usernameField = .autofilled(username)
        passwordField = .autofilled(password)
    }

    func updateValues(username: String?, password: String?, userInput: Bool) {
        if let username = username, !username.isEmpty, username != usernameField.value {
            Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Storing new username from submit: \(username)", category: .passwordManagerInternal)
            if userInput {
                usernameField = .userInput(username)
                isDirty = true
            } else {
                usernameField = .initial(username)
            }
        }
        if let password = password, !password.isEmpty, password != passwordField.value {
            Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Storing new password from submit", category: .passwordManagerInternal)
            if userInput {
                passwordField = .userInput(password)
                isDirty = true
            } else {
                passwordField = .initial(password)
            }
        }
    }

    func suggestedEntry() -> PasswordManagerEntry? {
        guard let minimizedHost = autofilledHost ?? currentHost,
              let username = usernameField.value
        else { return nil }
        switch usernameField {
        case .autofilled:
            Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Suggested entry: \(username) on \(minimizedHost)", category: .passwordManagerInternal)
            return PasswordManagerEntry(minimizedHost: minimizedHost, username: username)
        default:
            let matchingEntries = passwordManager.bestMatchingEntries(hostname: minimizedHost, username: username)
            Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Suggested entries: \(matchingEntries)", category: .passwordManagerInternal)
            return matchingEntries.first
        }
    }

    func storeGeneratedPassword(_ password: String) {
        passwordField = .generated(password)
        isDirty = true
    }

    func unsavedCredentials(allowEmptyUsername: Bool) -> StoredCredentials? {
        Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Checking unsaved status: dirty = \(isDirty), has password = \(passwordField.value != nil)", category: .passwordManagerInternal)
        guard isDirty else { return nil }
        guard let password = passwordField.value, !password.isEmpty else { return nil }
        guard allowEmptyUsername || !(usernameField.value?.isEmpty ?? true) else { return nil }
        guard !(usernameField.isAutofilled && passwordField.isAutofilled) else { return nil }
        return StoredCredentials(username: usernameField.value, password: password, askSaveConfirmation: true)
    }

    func markSaved() {
        Logger.shared.logDebug("PasswordManagerCredentialsBuilder: Saved", category: .passwordManagerInternal)
        isDirty = false
    }

    private func reset() {
        autofilledHost = nil
        usernameField = .none
        passwordField = .none
        isDirty = false
    }
}
