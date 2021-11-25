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
    let waitHelper = WaitHelper()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        testRailPrint("Given I enable onboarding")
        BeamUITestsHelper(launchApp().app).tapCommand(.showOnboarding)
    }
    
    func testTermsConditionsAndPrivacyPolicy() {
        testRailPrint("Then by default no terms / privacy pop-up windows opened")
        XCTAssertFalse(onboardingView.isTermsAndConditionsWindowOpened())
        XCTAssertFalse(onboardingView.isPrivacyPolicyWindowOpened())
        
        testRailPrint("Then Privacy policy pop-up can be opened on demand")
        XCTAssertTrue(onboardingView.openPrivacyPolicyWindow().isPrivacyPolicyWindowOpened())
        XCTAssertFalse(onboardingView.isTermsAndConditionsWindowOpened())
        
        testRailPrint("Then Privacy policy pop-up can be closed on demand")
        XCTAssertFalse(onboardingView.closePrivacyPolicysWindow().isPrivacyPolicyWindowOpened())
        
        testRailPrint("Then Terms and conditions pop-up can be opened on demand")
        XCTAssertTrue(onboardingView.openTermsAndConditionsWindow().isTermsAndConditionsWindowOpened())
        XCTAssertFalse(onboardingView.isPrivacyPolicyWindowOpened())
        
        testRailPrint("Then Terms and conditions pop-up can be closed on demand")
        XCTAssertFalse(onboardingView.closeTermsAndConditionsWindow().isTermsAndConditionsWindowOpened())
    }
    
    func testConnectWithGoogle() {
        testRailPrint("Then Google auth window is opened on Continue with Google button click")
        XCTAssertTrue(onboardingView.clickContinueWithGoogleButton().isGoogleAuthWindowOpened())
        
        testRailPrint("When I close Google auth window")
        onboardingView.closeGoogleAuthWindow()
        
        testRailPrint("Then Google auth window is closed")
        XCTAssertTrue(waitHelper.waitForDoesntExist(onboardingView.getGoogleAuthWindow()))
        
        testRailPrint("Then user is still on Onboarding landing page")
        XCTAssertTrue(onboardingView.isOnboardingPageOpened())
    }
    
    func testConnectWithEmailUsernameRequirements() throws {
        testRailPrint("Then by default Connect button is disabled and Forgot password link is enabled")
        XCTAssertTrue(onboardingView.clickContinueWithEmailButton().waitForUsernameViewOpened())
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        XCTAssertTrue(onboardingUsernameView.getForgotPasswordLink().isEnabled)
        
        testRailPrint("Then clicking Enter button doesn't do anything")
        onboardingUsernameView.typeKeyboardKey(.escape) //get rid on Apple password window
        onboardingUsernameView.typeKeyboardKey(.enter) //it will fail with next steps if bug appears, no assertion possible due to Vynil limitation so far
        
        testRailPrint("Then I'm redirected to Landing view on pressing Back button")
        XCTAssertTrue(onboardingUsernameView.goToPreviousPage().isOnboardingPageOpened())
        XCTAssertTrue(onboardingView.clickContinueWithEmailButton().waitForUsernameViewOpened())
         
        testRailPrint("Then by default no password requirements label is displayed")
        XCTAssertFalse(onboardingUsernameView.isPasswordRequirementsLabelDisplayed())
        
        testRailPrint("When I populate email and password fields with acceptable input")
        onboardingUsernameView.typeKeyboardKey(.escape)
        onboardingUsernameView.getEmailTextField().clickAndType("ab1@xyz.com")
        onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
        onboardingUsernameView.pasteText(textToPaste: "abcdefg1!")
        onboardingUsernameView.typeKeyboardKey(.escape)
        
        testRailPrint("Then by default no password requirements label is displayed")
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        XCTAssertTrue(onboardingUsernameView.isPasswordRequirementsLabelDisplayed())
        
        testRailPrint("Then Connect button is disabled when having 7 chars for pasword")
        onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
        onboardingUsernameView.typeKeyboardKey(.delete, 2)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with 8 chars including 1 symbol for pasword, but no digits")
        onboardingUsernameView.pasteText(textToPaste: "!")
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with 9 chars including 1 symbol and 1 digit for pasword")
        onboardingUsernameView.pasteText(textToPaste: "1")
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with 1 char in top level domain")
        onboardingUsernameView.getEmailTextField().tapInTheMiddle()
        onboardingUsernameView.typeKeyboardKey(.delete, 2)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with 2 chars in high level top domain")
        onboardingUsernameView.getEmailTextField().typeText("a")
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with no dot between top level domain and domain")
        onboardingUsernameView.typeKeyboardKey(.leftArrow, 2)
        onboardingUsernameView.typeKeyboardKey(.delete)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with a dot between top level domain and domain")
        onboardingUsernameView.getEmailTextField().typeText(".")
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with no @ between email address and domain")
        onboardingUsernameView.typeKeyboardKey(.leftArrow, 4)
        onboardingUsernameView.typeKeyboardKey(.delete)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with two @ between email address and domain")
        onboardingUsernameView.getEmailTextField().typeText("@@")
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with single @ between email address and domain")
        onboardingUsernameView.typeKeyboardKey(.delete)
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is disabled with symbols in email name")
        onboardingUsernameView.typeKeyboardKey(.leftArrow, 2)
        onboardingUsernameView.getEmailTextField().typeText("!#")
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with no symbols in email name")
        onboardingUsernameView.typeKeyboardKey(.delete, 2)
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        
        testRailPrint("Then Connect button is enabled with a dot symbol in email name")
        onboardingUsernameView.getEmailTextField().typeText(".")
        XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
    }
    
    func testSignUpLater() {
        testRailPrint("Then Journal is opened on Sign up later click")
        XCTAssertTrue(onboardingView.signUpLater()
                        .clickSkipButton()
                        .waitForJournalViewToLoad()
                        .isJournalOpened())
    }
    
}
