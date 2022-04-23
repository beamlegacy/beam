//
//  OnboardingPrivateKeyViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 12/04/2022.
//

import Foundation

enum OnboardingPrivateKeyViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case importButton = "beamkey_import_continue"
        case backButton = "Back"
        case cantFindPKButton = "I can’t find my private key"
        case importPKButton = "Import beamkey file..."
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case pkViewTitle = "Enter your private key"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case privateKeyTextField = "Paste your private key"
    }
    
}
