//
//  PrivacyAllowListPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation

enum PrivacyAllowListPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case addUrl = "basicAdd"
        case removeUrl = "basicRemove"
        case cancelButton = "Cancel"
        case saveButton = "Save"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "Search"
    }
}
