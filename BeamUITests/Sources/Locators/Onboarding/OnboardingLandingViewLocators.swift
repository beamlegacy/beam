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
        case continueWithEmailButton = "Continue with Email"
        case termsAndConditionsButton = "Terms and Conditions"
        case privacyPolicyButton = "Privacy Policy"
        case signUpLaterButton = "Sign up later, alligator!"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case googleAuthWindowText = "Google"
        case onboardingTitle = "Welcome to Beam"
    }

}
