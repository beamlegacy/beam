//
//  PasswordPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 17/02/2022.
//

import Foundation

enum PasswordPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case detailsButton = "Details…"
        case fillButton = "basicAdd"
        case removeButton = "basicRemove"
        case exportButton = "Export…"
        case cancelButton = "Cancel"
        case addPasswordButton = "Add Password"
        case addCardButton = "Add Card"
        case doneButton = "Done"
        case editButton = "Edit..."
        case addCreditCardButton = "addCreditCard"
        case removeCreditCardButton = "removeCreditCard"
        case unlockButton = "Unlock"
    }

    enum Groups: String, CaseIterable, UIElement {
        case addRemovePassword = "addRemovePassword"
        case addRemoveCreditCard = "addRemoveCreditCard"
    }

    enum Pickers: String, CaseIterable, UIElement {
        case importPicker = "Import…" // not a button anymore
    }

    enum CheckboxTexts: String, CaseIterable, UIElement {
        case autofillPasswords = "Autofill usernames and passwords"
        case autofillCC = "Credit cards"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "Search"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case siteError = "Website URL is invalid"
        case passwordProtectionTitle = "Passwords Are Locked"
        case passwordProtectionDescription = "Click the Unlock button to Touch ID or enter the password for the user "
    }
    
    enum Other: String, CaseIterable, UIElement {
        case creditCards = "Credit Cards"
    }
}
