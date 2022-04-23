//
//  OnboardingLostPKTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 14.04.2022.
//

import Foundation
import XCTest

class OnboardingLostPKTestView: BaseView {
    
    func waitForLostPKViewLoading() -> Bool {
        return staticText(OnboardingLostPKViewLocators.StaticTexts.viewTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func getViewDescription() -> XCUIElement {
        return staticText("If you have lost your private key, the only way to gain back access to your account is to permanently delete all your data.")
    }
    
    func getViewWarningText() -> XCUIElement {
        return staticText(OnboardingLostPKViewLocators.StaticTexts.viewWarningText.accessibilityIdentifier)
    }
    
    func getEraseDataButton() -> XCUIElement {
        return button(OnboardingLostPKViewLocators.Buttons.eraseAllButton.accessibilityIdentifier)
    }
    
    func getBackButton() -> XCUIElement {
        return staticText(OnboardingLostPKViewLocators.Buttons.backButton.accessibilityIdentifier)
    }
    
}
