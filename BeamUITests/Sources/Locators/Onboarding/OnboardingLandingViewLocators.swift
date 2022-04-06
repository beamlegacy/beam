//
//  OnboardingViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation

enum OnboardingLandingViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case continueWithGoogleButton = "Continue with Google"
        case continueWithEmailButton = "continue-with-email"
        case continueWithEmailButtonDisabled = "continue-with-email-disabled"
        case termsAndConditionsButton = "Terms and Conditions"
        case privacyPolicyButton = "Privacy Policy"
        case signUpLaterButton = "Sign Up/In Later"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case googleAuthWindowText = "Google"
        case onboardingTitle = "Welcome to Beam"
    }
    
    enum TextFields: String, CaseIterable, UIElement {
        case emailTextField = "emailField"
    }

}
