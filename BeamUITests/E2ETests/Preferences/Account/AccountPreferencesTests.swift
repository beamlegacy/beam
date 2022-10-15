//
//  AccountPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 21.06.2022.
//

import Foundation
import XCTest

class AccountPreferencesTests: BaseTest {
    
    var accountView: AccountTestView!
    var alertView: AlertTestView!
    let allNotes = AllNotesTestView()
    
    override func setUp() {
        step ("GIVEN I sign up with new account") {
            super.setUp()
            signUpStagingWithRandomAccount()
        }
    }
    
    private func openAccountPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .account)
    }
    
    func testSavePrivateKey() {
        testrailId("C623")
        let expectedPKName = "private.beamkey"
        let dialogueTitle = "Save"
        
        step ("WHEN I click Save PK button") {
            self.openAccountPrefs()
            accountView = AccountTestView()
            XCTAssertTrue(accountView.staticText(AccountViewLocators.StaticTexts.pkLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            accountView.clickSavePKButton()
        }
        
        step ("WHEN I see native Save dialog opened with \(expectedPKName)") {
            XCTAssertTrue(accountView.app.dialogs[dialogueTitle].waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertEqual(accountView.app.dialogs[dialogueTitle].textFields["saveAsNameTextField"].firstMatch.getStringValue(), expectedPKName)
        }
    }
    
    func testDeleteDB() {
        testrailId("C624")
        step ("GIVEN I add some notes and open Account preferences") {
            uiMenu.invoke(.create10Notes)
            self.openAccountPrefs()
            accountView = AccountTestView()
            XCTAssertTrue(accountView.staticText(AccountViewLocators.StaticTexts.deleteDBLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step ("WHEN I cancel Deletion of the DB") {
            alertView = accountView.clickDeleteDBButton()
            XCTAssertTrue(AlertTestView().getAlertDialog().staticTexts[AlertViewLocators.StaticTexts.deleteDBConfirmation.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            alertView.getAlertDialog().buttons[AlertViewLocators.Buttons.cancelButton.accessibilityIdentifier].clickOnExistence()
        }
        
        step ("THEN I see all notes") {
            shortcutHelper.shortcutActionInvoke(action: .close)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            XCTAssertGreaterThan(AllNotesTestTable().numberOfVisibleItems, 10)
        }
        
        step ("WHEN I confirm Deletion of the DB") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            accountView
                .clickDeleteDBButton()
                .getAlertDialog().buttons[AlertViewLocators.Buttons.deleteButton.accessibilityIdentifier].clickOnExistence()
        }
        
        step ("THEN I'm on Onboarding landing page" ) {
            XCTAssertTrue(OnboardingLandingTestView().waitForLandingViewToLoad())
        }
        
        step ("WHEN I open all notes") {
            OnboardingMinimalTestView()
                .continueOnboarding()
                .clickSkipButton()
                .closeTab()
            JournalTestView()
                .waitForJournalViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
        }
        
        step ("THEN default notes are displayed" ) {
            XCTAssertEqual(AllNotesTestTable().numberOfVisibleItems, 4)
        }
    }
    
    
    func testPKDisplayingAndCopying() throws {
        
        let expectedPKLength = 44
        
        step ("GIVEN I open account prefs") {
            self.openAccountPrefs()
        }
        
        testrailId("C621")
        step ("THEN I see correct PK format") {
            accountView = AccountTestView()
            XCTAssertTrue(accountView.staticText(AccountViewLocators.StaticTexts.encryptionLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            
            let pkString = accountView.getEncryptionKeyLabel().title
            let pkLength = pkString.count
            let pkLastCharIndex = pkString.index(pkString.startIndex, offsetBy: pkLength - 1)
            
            XCTAssertEqual(pkLength, expectedPKLength, "PK has incorrect length: \(pkLength)")
            XCTAssertEqual(pkString[pkLastCharIndex], "=", "PK ends with incorrect char")
        }
        
        testrailId("C622")
        step ("THEN I successfully copy PK") {
            accountView.getEncryptionKeyLabel().tapInTheMiddle()
            XCTAssertTrue(accountView.staticText("Encryption Key Copied!").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
