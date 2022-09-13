//
//  PrivacyAllowListPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Quentin Valero on 10/05/2022.
//

import Foundation

enum PrivacyAllowListPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case addURL = "basicAdd"
        case removeURL = "basicRemove"
        case cancelButton = "Cancel"
        case applyButton = "Apply"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "Search"
    }
}
