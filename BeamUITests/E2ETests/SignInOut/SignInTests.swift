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
    var accountInfo: AccountInformation!

    override func setUpWithError() throws {
        try super.setUpWithError()
        step("Given I enable onboarding") {
            launchApp()
            uiMenu.showOnboarding()
        }
    }
    
    private func assertSignUpFailure(email: String, password: String) {
        onboardingUsernameView.populateCredentialFields(email: email, password: incorrectPassword)
        waitFor(PredicateFormat.isEnabled.rawValue, onboardingUsernameView.getConnectButtonElement(), BaseTest.minimumWaitTimeout)
        XCTAssertFalse(onboardingUsernameView.isConnectButtonEnabled())
    }
    
    func testUseAppWithoutSignIn() {
        testrailId("C658")
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
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        }
            
        testrailId("C616")
        step("THEN there is no sign up later button on appeared sign in pop-up"){
            PreferencesBaseView().navigateTo(preferenceView: .account)
            AccountTestView().getConnectToBeamButtonElement().clickOnExistence()
            XCTAssertFalse(onboardingView.staticText(OnboardingLandingViewLocators.Buttons.signUpLaterButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
        
    func testSignInUsingInvalidCredentials() throws {
        try XCTSkipIf(true, "Is duplicated by testConnectWithEmailUsernameSignInRequirements. To be refactored/removed")
        step("GIVEN I sign up an account and take credentials") {
            setupStaging(withRandomAccount: true)
            accountInfo = getCredentials()
            deletePK = true
            uiMenu.showOnboarding()
                .deletePrivateKeys()
        }
        
        step("GIVEN Username view is opened"){
        XCTAssertTrue(onboardingView
                        .clickContinueWithEmailButton()
                        .waitForUsernameViewOpened(), "Username view wasn't opened")
        }

        step("THEN Connect button is disabled for incorrect password"){
            self.assertSignUpFailure(email: accountInfo.email, password: incorrectPassword)
        }
        
        step("THEN I successfully go back to initail view and returned to user credential view"){
        XCTAssertTrue(onboardingUsernameView
                        .clickBackButton()
                        .clickContinueWithEmailButton()
                        .waitForUsernameViewOpened(), "Username view wasn't opened")
        }
        
        step("THEN Connect button is disabled for incorrect email"){
        self.assertSignUpFailure(email: incorrectEmail, password: accountInfo.password)
        }
    }
    
    
}
