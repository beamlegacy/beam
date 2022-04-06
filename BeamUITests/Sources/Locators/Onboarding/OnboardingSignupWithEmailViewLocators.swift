//
//  OnboardingSignupWithEmailViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 04/04/2022.
//

import Foundation

enum OnboardingSignupWithEmailViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case signupButton = "connect_button"
        case backButton = "nav-back"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case passwordField = "passwordField"
        case passwordFieldEditing = "passwordField-editing"
        case passwordFieldVerify = "passwordFieldVerify"
        case passwordFieldVerifyEditing = "passwordFieldVerify-editing"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case passwordFormatInfoMessage = "Use at least 8 characters, 1 symbol and 1 number"
        case passwordVerifyEqualityInfoMessage = "Make sure your passwords match"
    }
    
}
