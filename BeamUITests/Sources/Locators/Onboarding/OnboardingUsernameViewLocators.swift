//
//  OnboardingUsernameViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation

enum OnboardingUsernameViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case skipButton = "skip_action"
        case goBackButton = "Back"
        case connectButton = "connect_button"
        case forgotPassword = "Forgot password"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case usernameViewTitle = "Connect with Email"
        case passwordRequirementsLabel = "Use at least 8 characters, 1 symbol and 1 number"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case emailField = "emailField"
        case emailFieldEditing = "emailField-editing"
        case passwordField = "passwordField"
        case passwordFieldEditing = "passwordField-editing"
    }
}
