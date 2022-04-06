//
//  OnboardingSignupWithEmailTestView.swift
//  BeamUITests
//
//  Created by Andrii on 04/04/2022.
//

import Foundation
import XCTest

class OnboardingSignupWithEmailTestView: BaseView {
    
    func getPasswordField() -> XCUIElement {
        return secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordField.accessibilityIdentifier).exists ? secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordField.accessibilityIdentifier) : secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordFieldEditing.accessibilityIdentifier)
    }
    
    func getVerifyPasswordField() -> XCUIElement {
        return secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordFieldVerify.accessibilityIdentifier).exists ? secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordFieldVerify.accessibilityIdentifier) : secureTextField(OnboardingSignupWithEmailViewLocators.TextFields.passwordFieldVerifyEditing.accessibilityIdentifier)
    }
    
    func getSignUpButton() -> XCUIElement {
        return button(OnboardingSignupWithEmailViewLocators.Buttons.signupButton.accessibilityIdentifier)
    }
    
    func clickBackButton() -> OnboardingLandingTestView {
        let backButton = image(OnboardingSignupWithEmailViewLocators.Buttons.backButton.accessibilityIdentifier)
        backButton.hoverAndTapInTheMiddle()
        return OnboardingLandingTestView()
    }
    
    func clickSignUpButton() -> OnboardingAccountConfirmationTestView {
        let signUpButton = staticText(OnboardingSignupWithEmailViewLocators.Buttons.signupButton.accessibilityIdentifier)
        signUpButton.hoverAndTapInTheMiddle()
        return OnboardingAccountConfirmationTestView()
    }
    
    @discardableResult
    func waitForSignUpButtonToBeEnabled() -> Bool {
        return waitForIsEnabled(getSignUpButton())
    }
    
    @discardableResult
    func waitForSignUpButtonToBeDisabled() -> Bool {
        return waitForIsDisabled(getSignUpButton())
    }
    
    func waitForVerifyPasswordsEqualityMessageExistence() -> Bool {
        return staticText(OnboardingSignupWithEmailViewLocators.StaticTexts.passwordVerifyEqualityInfoMessage.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func waitForPasswordFormatMessageExistence() -> Bool {
        return staticText(OnboardingSignupWithEmailViewLocators.StaticTexts.passwordFormatInfoMessage.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
}
