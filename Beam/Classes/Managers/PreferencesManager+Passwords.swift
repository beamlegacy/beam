//
//  PreferencesManager+Passwords.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/07/2021.
//

import Foundation

// MARK: - Keys
extension PreferencesManager {
    static let autofillUsernamePasswordsKey = "autofillUsernamePasswords"
    static let autofillAdressesKey = "autofillAdresses"
    static let autofillCreditCardsKey = "autofillCreditCards"
}

// MARK: - Default Values
extension PreferencesManager {
    static let autofillUsernamePasswordsDefault = true
    static let autofillAdressesDefault = true
    static let autofillCreditCardsDefault = true
}

extension PreferencesManager {
    @UserDefault(key: autofillUsernamePasswordsKey, defaultValue: autofillUsernamePasswordsDefault, suiteName: BeamUserDefaults.passwordsPreferences.suiteName)
    static var autofillUsernamePasswords: Bool

    @UserDefault(key: autofillAdressesKey, defaultValue: autofillAdressesDefault, suiteName: BeamUserDefaults.passwordsPreferences.suiteName)
    static var autofillAdresses: Bool

    @UserDefault(key: autofillCreditCardsKey, defaultValue: autofillCreditCardsDefault, suiteName: BeamUserDefaults.passwordsPreferences.suiteName)
    static var autofillCreditCards: Bool
}
