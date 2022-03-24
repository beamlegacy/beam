//
//  SignInTests.swift
//  BeamUITests
//
//  Created by Andrii on 21/03/2022.
//

import Foundation
import XCTest

class SigninTests: BaseTest {
    
    let onboardingView = OnboardingLandingTestView()
    let onboardingUsernameView = OnboardingUsernameTestView()
    let onboardingImportView = OnboardingImportDataTestView()
    let shortcuts = ShortcutsHelper()
    
    let correctEmail = "qa+autotestsignin@beamapp.co"
    let incorrectEmail = "qa+autotestsignin@beamappa.co"
    let correctPassword = "JKRZ6#ykhm_6KR!"
    let incorrectPassword = "Incorrect1"
    let username = "AutomationTestSignin"
    
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        step("Given I enable onboarding") {
            let journalView = launchApp()
            BeamUITestsHelper(journalView.app).tapCommand(.showOnboarding)
        }
    }
    
    private func assertSignUpFailure(email: String, password: String) {
        onboardingUsernameView.populateCredentialFields(email: correctEmail, password: incorrectPassword)
        waitFor(PredicateFormat.isEnabled.rawValue, onboardingUsernameView.getConnectButtonElement(), BaseTest.minimumWaitTimeout)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
    }
    
    func testUseAppWithoutSignIn() {
        step("WHEN I choose to sign up later"){
            onboardingView.signUpLater()
        }
            
        step("THEN I am not asked for credentials and I'm on Journal"){
            XCTAssertTrue(onboardingImportView
                .clickSkipButton()
                .waitForJournalViewToLoad()
                .isJournalOpened(), "Journal view didn't load")
        }
            
        step("THEN I'm not in signed in state"){
            shortcuts.shortcutActionInvoke(action: .openPreferences)
        }
            
        step("THEN there is no sign up later button on appeared sign in pop-up"){
            PreferencesBaseView().navigateTo(preferenceView: .account)
            AccountTestView().getConnectToBeamButtonElement().clickOnExistence()
            XCTAssertFalse(onboardingView.staticText(OnboardingLandingViewLocators.Buttons.signUpLaterButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
        
    func testSignInSuccessfullyFromOnboarding() throws {
        try XCTSkipIf(true, "WIP")
        step("TBD"){
        XCTAssertTrue(onboardingView.clickContinueWithEmailButton().waitForUsernameViewOpened(), "Username view wasn't opened")
        }
        
        step("TBD"){
        XCTAssertTrue(onboardingUsernameView
                        .populateCredentialFields(email: correctEmail, password: correctPassword)
                        .clickConnectButton()
                        .clickSkipButton()
                        .waitForJournalViewToLoad()
                        .isJournalOpened(), "Journal view didn't load")
        }
    }
        
    func testSignInUsingInvalidCredentials() throws {
        
        step("GIVEN Username view is opened"){
        XCTAssertTrue(onboardingView
                        .clickContinueWithEmailButton()
                        .waitForUsernameViewOpened(), "Username view wasn't opened")
        }

        step("THEN Connect button is disabled for incorrect password"){
        self.assertSignUpFailure(email: correctEmail, password: incorrectPassword)
        }
        
        step("THEN I successfully go back to initail view and returned to user credential view"){
        XCTAssertTrue(onboardingUsernameView
                        .clickBackButton()
                        .clickContinueWithEmailButton()
                        .waitForUsernameViewOpened(), "Username view wasn't opened")
        }
        
        step("THEN Connect button is disabled for incorrect email"){
        self.assertSignUpFailure(email: incorrectEmail, password: correctPassword)
        }
    }
    
    
}
