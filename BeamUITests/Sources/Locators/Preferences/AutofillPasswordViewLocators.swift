//
//  PasswordViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation

enum AutofillPasswordViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case cancelButton = "Cancel"
        case fillButton = "Fill"
        case removeButton = "Remove"
    }

    enum StaticTexts: String, CaseIterable, UIElement {
        case windowTitle = "Choose a login to fill"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case searchField = "Search"
    }
}
