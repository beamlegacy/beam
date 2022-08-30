//
//  AboutPreferencesViewLocators.swift
//  BeamUITests
//
//  Created by Andrii on 07/04/2022.
//

import Foundation

enum AboutPreferencesViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case reportBugButton = "Report a bug..."
        case reportFeatureButton = "Feature Request..."
        case followTwitterButton = "Follow"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case termsOfServicesHyperlink = "Terms of Service"
        case privacyPolicyHyperlink = "Privacy Policy"
    }
    
}
