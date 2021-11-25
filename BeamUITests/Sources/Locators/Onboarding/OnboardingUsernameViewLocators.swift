//
//  OnboardingUsernameViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation

enum OnboardingUsernameViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case skipButton = "Skip"
        case goBackButton = "onboarding-back"
        case connectButton = "connect_button"
        case forgotPassword = "Forgot password"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case usernameViewTitle = "Connect to Beam"
        case passwordRequirementsLabel = "Use at least 8 characters, 1 symbol and 1 number"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case emailField = "emailField"
        case emailFieldEditing = "emailField-editing"
        case passwordField = "passwordField"
        case passwordFieldEditing = "passwordField-editing"
    }
}
