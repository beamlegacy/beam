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
        step("Given I enable onboarding"){
            BeamUITestsHelper(launchApp().app).tapCommand(.showOnboarding)
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
            XCTAssertTrue(waitHelper.waitForDoesntExist(onboardingView.getGoogleAuthWindow()))
        }
        
        step("And user is still on Onboarding landing page"){
            XCTAssertTrue(onboardingView.isOnboardingPageOpened())
        }
    }
    
    func testConnectWithEmailUsernameRequirements() throws {
        
        step("Then by default Connect button is disabled and Forgot password link is enabled"){
            XCTAssertTrue(onboardingView.clickContinueWithEmailButton().waitForUsernameViewOpened())
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
            XCTAssertTrue(onboardingUsernameView.getForgotPasswordLink().isEnabled)
        }
        
        step("Then clicking Enter button doesn't do anything"){
            onboardingUsernameView.typeKeyboardKey(.escape) //get rid on Apple password window
            onboardingUsernameView.typeKeyboardKey(.enter) //it will fail with next steps if bug appears, no assertion possible due to Vynil limitation so far
        }
        
        step("And I'm redirected to Landing view on pressing Back button"){
            XCTAssertTrue(onboardingUsernameView.goToPreviousPage().isOnboardingPageOpened())
            XCTAssertTrue(onboardingView.clickContinueWithEmailButton().waitForUsernameViewOpened())
        }
        
        step("Then by default no password requirements label is displayed"){
            XCTAssertFalse(onboardingUsernameView.isPasswordRequirementsLabelDisplayed())
        }
        
        step("When I populate email and password fields with acceptable input"){
            onboardingUsernameView.typeKeyboardKey(.escape)
            onboardingUsernameView.getEmailTextField().clickAndType("ab1@xyz.com")
            onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
            onboardingUsernameView.pasteText(textToPaste: "abcdefg1!")
            onboardingUsernameView.typeKeyboardKey(.escape)
        }
        
        step("Then by default no password requirements label is displayed"){
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
            XCTAssertTrue(onboardingUsernameView.isPasswordRequirementsLabelDisplayed())
        }
        
        step("And Connect button is disabled when having 7 chars for pasword"){
            onboardingUsernameView.getPasswordTextField().tapInTheMiddle()
            onboardingUsernameView.typeKeyboardKey(.delete, 2)
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with 8 chars including 1 symbol for pasword, but no digits"){
            onboardingUsernameView.pasteText(textToPaste: "!")
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with 9 chars including 1 symbol and 1 digit for pasword"){
            onboardingUsernameView.pasteText(textToPaste: "1")
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with 1 char in top level domain"){
            onboardingUsernameView.getEmailTextField().tapInTheMiddle()
            onboardingUsernameView.typeKeyboardKey(.delete, 2)
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with 2 chars in high level top domain"){
            onboardingUsernameView.getEmailTextField().typeText("a")
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with no dot between top level domain and domain"){
            onboardingUsernameView.typeKeyboardKey(.leftArrow, 2)
            onboardingUsernameView.typeKeyboardKey(.delete)
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with a dot between top level domain and domain"){
            onboardingUsernameView.getEmailTextField().typeText(".")
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with no @ between email address and domain"){
            onboardingUsernameView.typeKeyboardKey(.leftArrow, 4)
            onboardingUsernameView.typeKeyboardKey(.delete)
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with two @ between email address and domain"){
            onboardingUsernameView.getEmailTextField().typeText("@@")
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with single @ between email address and domain"){
            onboardingUsernameView.typeKeyboardKey(.delete)
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is disabled with symbols in email name"){
            onboardingUsernameView.typeKeyboardKey(.leftArrow, 2)
            onboardingUsernameView.getEmailTextField().typeText("!#")
            XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with no symbols in email name"){
            onboardingUsernameView.typeKeyboardKey(.delete, 2)
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
        }
        
        step("And Connect button is enabled with a dot symbol in email name"){
            onboardingUsernameView.getEmailTextField().typeText(".")
            XCTAssertTrue(onboardingUsernameView.isConnectButtonEnabled())
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
