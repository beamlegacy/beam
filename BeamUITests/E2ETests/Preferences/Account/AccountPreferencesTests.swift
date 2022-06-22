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
    
    override func setUp() {
        step ("GIVEN I sign up with new account") {
            setupStaging(withRandomAccount: true)
        }
    }
    
    private func openAccountPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .account)
    }
    
    func testSavePrivateKey() {
        
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
            XCTAssertEqual(accountView.getElementStringValue(element:  accountView.app.dialogs[dialogueTitle].textFields["saveAsNameTextField"].firstMatch), expectedPKName)
        }
    }
    
    func testDeleteDB() {
        
        step ("GIVEN I add some notes and open Account preferences") {
            uiMenu.resizeSquare1000()
            uiMenu.create10Notes()
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
            AllNotesTestView().waitForAllNotesViewToLoad()
            XCTAssertEqual(AllNotesTestTable().numberOfVisibleItems, 14)
        }
        
        step ("WHEN I confirm Deletion of the DB") {
            self.openAccountPrefs()
            accountView
                .clickDeleteDBButton()
                .getAlertDialog().buttons[AlertViewLocators.Buttons.deleteButton.accessibilityIdentifier].clickOnExistence()
        }
        
        step ("THEN I'm on Onboarding landing page" ) {
            XCTAssertTrue(OnboardingLandingTestView().waitForLandingViewToLoad())
        }
        
        step ("WHEN I open all notes") {
            OnboardingLandingTestView()
                .signUpLater()
                .clickSkipButton()
                .waitForJournalViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            AllNotesTestView().waitForAllNotesViewToLoad()
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
        
        step ("THEN I see correct PK format") {
            accountView = AccountTestView()
            XCTAssertTrue(accountView.staticText(AccountViewLocators.StaticTexts.encryptionLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            
            let pkString = accountView.getEncryptionKeyLabel().title
            let pkLength = pkString.count
            let pkLastCharIndex = pkString.index(pkString.startIndex, offsetBy: pkLength - 1)
            
            XCTAssertEqual(pkLength, expectedPKLength, "PK has incorrect length: \(pkLength)")
            XCTAssertEqual(pkString[pkLastCharIndex], "=", "PK ends with incorrect char")
        }
        
        step ("THEN I successfully copy PK") {
            accountView.getEncryptionKeyLabel().tapInTheMiddle()
            XCTAssertTrue(accountView.staticText("Encryption Key Copied!").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
