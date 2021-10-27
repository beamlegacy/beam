//
//  PreferencesToolbarViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation

enum PreferencesToolbarViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case generalButton = "General"
        case browserButton = "Browser"
        case cardsButton = "Cards"
        case privacyButton = "Privacy"
        case passwordsButton = "Passwords"
        case accountButton = "Account"
        case aboutButton = "About"
        case advancedButton = "Advanced"
    }

}
