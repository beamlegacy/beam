//
//  OnboardingUsernameTestView.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation
import XCTest

class OnboardingUsernameTestView: BaseView {
    
    func getEmailTextField() -> XCUIElement {
        return textField(OnboardingUsernameViewLocators.TextFields.emailField.accessibilityIdentifier).exists ? textField(OnboardingUsernameViewLocators.TextFields.emailField.accessibilityIdentifier) : textField(OnboardingUsernameViewLocators.TextFields.emailFieldEditing.accessibilityIdentifier)
    }
    
    func getPasswordTextField() -> XCUIElement {
        return secureTextField(OnboardingUsernameViewLocators.TextFields.passwordField.accessibilityIdentifier).exists ? secureTextField(OnboardingUsernameViewLocators.TextFields.passwordField.accessibilityIdentifier) : secureTextField(OnboardingUsernameViewLocators.TextFields.passwordFieldEditing.accessibilityIdentifier)
    }
    
    func getForgotPasswordLink() -> XCUIElement {
        return staticText(OnboardingUsernameViewLocators.Buttons.forgotPassword.accessibilityIdentifier)
    }
    
    func goToPreviousPage() -> OnboardingLandingTestView {
        let backButton = image(OnboardingUsernameViewLocators.Buttons.goBackButton.accessibilityIdentifier)
        backButton.hover()
        backButton.clickOnExistence()
        return OnboardingLandingTestView()
    }
    
    @discardableResult
    func clickSkipButton() -> JournalTestView {
        staticText(OnboardingUsernameViewLocators.Buttons.skipButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
    func isConnectButtonEnabled() -> Bool {
        return button(OnboardingUsernameViewLocators.Buttons.connectButton.accessibilityIdentifier).isEnabled
    }
    
    @discardableResult
    func waitForUsernameViewOpened() -> Bool {
        return staticText(OnboardingUsernameViewLocators.StaticTexts.usernameViewTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isPasswordRequirementsLabelDisplayed() -> Bool {
        return staticText(OnboardingUsernameViewLocators.StaticTexts.passwordRequirementsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
}
