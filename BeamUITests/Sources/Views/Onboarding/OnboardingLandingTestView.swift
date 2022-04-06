//
//  OnboardingTestView.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation
import XCTest

class OnboardingLandingTestView: BaseView {
    
    func getConnectWithEmailButton() -> XCUIElement {
        return button(OnboardingLandingViewLocators.Buttons.continueWithEmailButton.accessibilityIdentifier)
    }
    
    func getEmailTextField() -> XCUIElement {
        return textField(OnboardingLandingViewLocators.TextFields.emailTextField.accessibilityIdentifier)
    }
    
    func getPrivacyPolicyWindow() -> XCUIElement {
        return app.windows[OnboardingLandingViewLocators.Buttons.privacyPolicyButton.accessibilityIdentifier]
    }
    
    func getTermsAndConditionWindow() -> XCUIElement {
        return app.windows[OnboardingLandingViewLocators.Buttons.termsAndConditionsButton.accessibilityIdentifier]
    }
    
    func getGoogleAuthWindow() -> XCUIElement {
        return app.windows[OnboardingLandingViewLocators.StaticTexts.googleAuthWindowText.accessibilityIdentifier]
    }
    
    @discardableResult
    func signUpLater() -> OnboardingUsernameTestView {
        staticText(OnboardingLandingViewLocators.Buttons.signUpLaterButton.accessibilityIdentifier).clickOnExistence()
        return OnboardingUsernameTestView()
    }
    
    @discardableResult
    func openTermsAndConditionsWindow() -> OnboardingLandingTestView {
        staticText(OnboardingLandingViewLocators.Buttons.termsAndConditionsButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func isTermsAndConditionsWindowOpened() -> Bool {
        return self.getTermsAndConditionWindow().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func closeTermsAndConditionsWindow() -> OnboardingLandingTestView {
        self.getTermsAndConditionWindow().buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        return self
    }
    
    @discardableResult
    func openPrivacyPolicyWindow() -> OnboardingLandingTestView {
        staticText(OnboardingLandingViewLocators.Buttons.privacyPolicyButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func isPrivacyPolicyWindowOpened() -> Bool {
        return self.getPrivacyPolicyWindow().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func closePrivacyPolicysWindow() -> OnboardingLandingTestView {
        self.getPrivacyPolicyWindow().buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        return self
    }
    
    @discardableResult
    func clickContinueWithGoogleButton() -> OnboardingLandingTestView {
        button(OnboardingLandingViewLocators.Buttons.continueWithGoogleButton.accessibilityIdentifier).clickOnExistence()
        return self
    }
    
    func isGoogleAuthWindowOpened() -> Bool {
        return self.getGoogleAuthWindow().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func closeGoogleAuthWindow() -> OnboardingLandingTestView {
        self.getGoogleAuthWindow().buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        return self
    }
    
    func isOnboardingPageOpened() -> Bool {
        return staticText(OnboardingLandingViewLocators.StaticTexts.onboardingTitle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    @discardableResult
    func clickContinueWithEmailButton() -> OnboardingUsernameTestView {
        getConnectWithEmailButton().clickOnHittable()
        return OnboardingUsernameTestView()
    }
    
    func isContinueWithEmailButtonActivated() -> Bool {
        return waitFor(PredicateFormat.isHittable.rawValue, getConnectWithEmailButton(), minimumWaitTimeout)  
    }
}
