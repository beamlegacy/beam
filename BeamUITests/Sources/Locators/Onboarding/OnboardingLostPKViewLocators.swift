//
//  OnboardingLostPKViewLocators.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 14.04.2022.
//

import Foundation

enum OnboardingLostPKViewLocators {
    
    enum Buttons: String, CaseIterable, UIElement {
        case eraseAllButton = "Erase all data"
        case backButton = "Back"
    }
    
    enum StaticTexts: String, CaseIterable, UIElement {
        case viewTitle = "Lost private key"
        case viewWarningText = "This operation cannot be undone."
    }
    
}
