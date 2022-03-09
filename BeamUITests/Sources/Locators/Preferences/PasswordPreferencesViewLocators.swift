//
//  PasswordPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 17/02/2022.
//

import Foundation

enum PasswordPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case detailsButton = "Details..."
        case fillButton = "basicAdd"
        case removeButton = "basicRemove"
        case importButton = "Import..."
        case exportButton = "Export..."
        case cancelButton = "Cancel"
        case addPasswordButton = "Add Password"
        case doneButton = "Done"
    }

    enum CheckboxTexts: String, CaseIterable, UIElement {
        case windowTitle = "Autofill usernames and passwords"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "Search"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case siteError = "Website URL is invalid"
    }
}
