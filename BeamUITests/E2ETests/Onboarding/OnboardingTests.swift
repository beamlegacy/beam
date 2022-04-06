//
//  OnboardingTests.swift
//  BeamUITests
//
//  Created by Andrii on 24/11/2021.
//

import Foundation
import XCTest

class OnboardingTests: BaseTest {
    
    let onboardingView = OnboardingLandingTestView()
    let onboardingUsernameView = OnboardingUsernameTestView()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        step("Given I enable onboarding"){
            //BeamUITestsHelper(launchApp().app).tapCommand(.showOnboarding)
            BeamUITestsHelper(launchAppWithArgument(uiTestModeLaunchArgument).app).tapCommand(.showOnboarding)
        }
    }
    
    func testTermsConditionsAndPrivacyPolicy() {
        step("Then by default no terms / privacy pop-up windows opened"){
            XCTAssertFalse(onboardingView.isTermsAndConditionsWindowOpened())
            XCTAssertFalse(onboardingView.isPrivacyPolicyWindowOpened())
        }
        
        step("Then Privacy policy pop-up can be opened on demand"){
            XCTAssertTrue(onboardingView.openPrivacyPolicyWindow().isPrivacyPolicyWindowOpened())
            XCTAssertFalse(onboardingView.isTermsAndConditionsWindowOpened())
        }
        
        step("And Privacy policy pop-up can be closed on demand"){
            XCTAssertFalse(onboardingView.closePrivacyPolicysWindow().isPrivacyPolicyWindowOpened())
        }
        
        step("And Terms and conditions pop-up can be opened on demand"){
            XCTAssertTrue(onboardingView.openTermsAndConditionsWindow().isTermsAndConditionsWindowOpened())
            XCTAssertFalse(onboardingView.isPrivacyPolicyWindowOpened())
        }
        
        step("And Terms and conditions pop-up can be closed on demand"){
            XCTAssertFalse(onboardingView.closeTermsAndConditionsWindow().isTermsAndConditionsWindowOpened())
        }
    }
    
    func testConnectWithGoogle() {
        step("Then Google auth window is opened on Continue with Google button click"){
            XCTAssertTrue(onboardingView.clickContinueWithGoogleButton().isGoogleAuthWindowOpened())
        }
        
        step("When I close Google auth window"){
            onboardingView.closeGoogleAuthWindow()
        }
        
        step("Then Google auth window is closed"){
            XCTAssertTrue(waitForDoesntExist(onboardingView.getGoogleAuthWindow()))
        }
        
        step("And user is still on Onboarding landing page"){
            XCTAssertTrue(onboardingView.isOnboardingPageOpened())
        }
    }
    
    func testConnectWithEmailUsernameSignInRequirements() throws {
        
        step("Then I can successfully edit email field and move to next view") {
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
            XCTAssertEqual(emptyString, onboardingView.getElementStringValue(element:  onboardingView.getEmailTextField()))

            onboardingView.getEmailTextField().tapInTheMiddle()
            onboardingView.getEmailTextField().typeText("abc")
            onboardingView.typeKeyboardKey(.delete, 3)
            onboardingView.getEmailTextField().typeText(correctEmail)
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("Then by default Connect button is disabled and Forgot password link is enabled"){
            onboardingView.clickContinueWithEmailButton()
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
            XCTAssertTrue(onboardingUsernameView.getForgotPasswordLink().isEnabled)
        }
        
        step("Then clicking Enter button doesn't do anything"){
            onboardingUsernameView.typeKeyboardKey(.enter) //it will fail with next steps if bug appears, no assertion possible due to Vynil limitation so far
        }
        
        step("And I'm redirected to Landing view on pressing Back button"){
            XCTAssertTrue(onboardingUsernameView.goToPreviousPage().isOnboardingPageOpened())
            onboardingView.clickContinueWithEmailButton()
        }
        
        step("Then incorrect password is not accepted"){
            onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
            onboardingUsernameView.getPasswordTextField().typeText(incorrectPassword)
            XCTAssertFalse(onboardingUsernameView.isCredentialsErrorDisplayed())
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
            onboardingUsernameView.clickConnectButton()
            XCTAssertTrue(onboardingUsernameView.isCredentialsErrorDisplayed())
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("Then correct password is accepted"){
            onboardingUsernameView.getPasswordTextField().click()
            ShortcutsHelper().shortcutActionInvoke(action: .selectAll)
            onboardingUsernameView.typeKeyboardKey(.delete)
            onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
            onboardingUsernameView.getPasswordTextField().typeText(correctPassword)
            XCTAssertFalse(onboardingUsernameView.isCredentialsErrorDisplayed())
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("Then correct email is displayed"){
            XCTAssertTrue(onboardingUsernameView.staticText(correctEmail).exists)
        }
    }
    
    func testConnectWithEmailSignUpPasswrdRequirements() throws {

        let onboardingSignupView = OnboardingSignupWithEmailTestView()
        
        step("Given I set correct password and click Continue with Email button") {
            onboardingView.getEmailTextField().tapInTheMiddle()
            onboardingView.getEmailTextField().typeText("ab1@xyz.com")
            onboardingView.clickContinueWithEmailButton()
        }
        
        step("Then I see no errors by default and Sign up button is disabled") {
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeDisabled())
            XCTAssertTrue(onboardingSignupView.waitForPasswordFormatMessageExistence())
            XCTAssertFalse(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }
        
        step("When I type 6 letter in Password field") {
            onboardingSignupView.getPasswordField().tapInTheMiddle()
            onboardingSignupView.getPasswordField().typeText("abcdef")
        }
        
        step("Then signup is disabled and Verify password shows an error") {
            onboardingSignupView.getVerifyPasswordField().tapInTheMiddle()
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeDisabled())
            XCTAssertTrue(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }
        
        step("When I type same 6 letter in Verify Password field") {
            onboardingSignupView.getVerifyPasswordField().typeText("abcdef")
        }
        
        step("Then signup is still disabled but Verify password doesn't show an error") {
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeDisabled())
            XCTAssertFalse(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }
        
        step("When I type 1 symbol and 1 number in Password field") {
            onboardingSignupView.getPasswordField().tapInTheMiddle()
            onboardingSignupView.getPasswordField().typeText("!1")
        }
        
        step("Then signup is disabled and Verify password doesn't show an error") {
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeDisabled())
            XCTAssertFalse(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }
        
        step("When I type same 1 char and 1 number in Verify Password field") {
            onboardingSignupView.getVerifyPasswordField().tapInTheMiddle()
            onboardingSignupView.getVerifyPasswordField().typeText("!1")
        }
        
        step("Then signup is enabled and Verify password doesn't show an error") {
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeEnabled())
            XCTAssertFalse(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }
        
        step("Then signup is disabled on Verify password input change") {
            onboardingSignupView.typeKeyboardKey(.delete)
            XCTAssertTrue(onboardingSignupView.waitForSignUpButtonToBeDisabled())
            XCTAssertTrue(onboardingSignupView.waitForVerifyPasswordsEqualityMessageExistence())
        }

    }
    
    func testConnectWithEmailFormatRequirements() {
        
        step("Given I type correct format email") {
            onboardingView.getEmailTextField().tapInTheMiddle()
            onboardingView.getEmailTextField().typeText("ab1@xyz.com")
        }
        
        step("And Connect button is disabled with 1 char in top level domain"){
            onboardingView.getEmailTextField().tapInTheMiddle()
            onboardingView.typeKeyboardKey(.delete, 2)
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is enabled with 2 chars in high level top domain"){
            onboardingView.getEmailTextField().typeText("a")
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is disabled with no dot between top level domain and domain"){
            onboardingView.typeKeyboardKey(.leftArrow, 2)
            onboardingView.typeKeyboardKey(.delete)
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is enabled with a dot between top level domain and domain"){
            onboardingView.getEmailTextField().typeText(".")
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is disabled with no @ between email address and domain"){
            onboardingView.typeKeyboardKey(.leftArrow, 4)
            onboardingView.typeKeyboardKey(.delete)
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is disabled with two @ between email address and domain"){
            onboardingView.getEmailTextField().typeText("@@")
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is enabled with single @ between email address and domain"){
            onboardingView.typeKeyboardKey(.delete)
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is disabled with symbols in email name"){
            onboardingView.typeKeyboardKey(.leftArrow, 2)
            onboardingView.getEmailTextField().typeText("!#")
            XCTAssertFalse(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is enabled with no symbols in email name"){
            onboardingView.typeKeyboardKey(.delete, 2)
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
        step("And Connect button is enabled with a dot symbol in email name"){
            onboardingView.getEmailTextField().typeText(".")
            XCTAssertTrue(onboardingView.isContinueWithEmailButtonActivated())
        }
        
    }

    
    func testSignUpLater() {
        
        step("Then Journal is opened on Sign up later click"){
            XCTAssertTrue(onboardingView.signUpLater()
                            .clickSkipButton()
                            .waitForJournalViewToLoad()
                            .isJournalOpened())
        }
        
    }
    
}
