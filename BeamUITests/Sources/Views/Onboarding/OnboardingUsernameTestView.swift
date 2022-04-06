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
        let backButton = staticText(OnboardingUsernameViewLocators.Buttons.goBackButton.accessibilityIdentifier)
        backButton.hover()
        backButton.clickOnExistence()
        return OnboardingLandingTestView()
    }
    
    @discardableResult
    func clickSkipButton() -> JournalTestView {
        button(OnboardingUsernameViewLocators.Buttons.skipButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
    func isConnectButtonEnabled() -> Bool {
        return waitFor(PredicateFormat.isEnabled.rawValue, getConnectButtonElement())
    }
    
    @discardableResult
    func waitForUsernameViewOpened() -> Bool {
        return staticText(OnboardingUsernameViewLocators.TextFields.passwordFieldSignup .accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isCredentialsErrorDisplayed() -> Bool {
        return staticText(OnboardingUsernameViewLocators.StaticTexts.invalidCredentialsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isPasswordRequirementsLabelDisplayed() -> Bool {
        return staticText(OnboardingUsernameViewLocators.StaticTexts.passwordRequirementsLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getConnectButtonElement() -> XCUIElement {
        return button(OnboardingUsernameViewLocators.Buttons.connectButton.accessibilityIdentifier)
    }
    
    @discardableResult
    func clickConnectButton() -> OnboardingImportDataTestView {
        getConnectButtonElement().clickOnHittable()
        return OnboardingImportDataTestView()
    }
    
    func clickBackButton() -> OnboardingLandingTestView {
        staticText(OnboardingUsernameViewLocators.Buttons.goBackButton.accessibilityIdentifier).clickOnExistence()
        return OnboardingLandingTestView()
    }
    
    @discardableResult
    func populateCredentialFields(email: String, password: String) -> OnboardingUsernameTestView {
        self.typeKeyboardKey(.escape) //required to get rid of apple keychain pop-up
        self.getEmailTextField().clickAndType(email)
        self.getPasswordTextField().tapInTheMiddle()
        self.pasteText(textToPaste: email)
        self.typeKeyboardKey(.escape) //required to get rid of apple keychain pop-up
        return self
    }
    
}
