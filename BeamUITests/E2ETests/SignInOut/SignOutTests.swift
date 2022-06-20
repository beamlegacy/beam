//
//  SignOutTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 15.06.2022.
//

import Foundation
import XCTest

class SignOutTests: BaseTest {
    
    let onboardingView = OnboardingLandingTestView()
    let alertView = AlertTestView()
    let accountView = AccountTestView()
    let allNotes = AllNotesTestView()
    
    override func setUp() {
        step("GIVEN I sign up creating 10 random notes") {
            setupStaging(withRandomAccount: true)
            webView.waitForWebViewToLoad()
        }
    }
    
    func testDeleteAllOnSignOut() {
        var defaultNotes: AllNotesTestTable!
        
        step("GIVEN I get the list of newly created notes 10 random notes") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            defaultNotes = AllNotesTestTable()
            shortcutHelper.shortcutActionInvoke(action: .showJournal)
            uiMenu.create10Notes()
        }
        
        step("WHEN I click Sign out button") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .account)
            accountView.signOutButtonClick()
        }
        
        step("THEN I see correct allert pop-up") {
            XCTAssertTrue(alertView.staticText(AlertViewLocators.StaticTexts.signOutConfirmation.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(alertView.isSettingEnabled(element: alertView.getDeleteAllCheckbox()))
        }
         
        step("WHEN I click cancel button") {
            alertView.cancelButtonClick()
            waitForDoesntExist(alertView.staticText(AlertViewLocators.StaticTexts.signOutConfirmation.accessibilityIdentifier))
        }
        
        step("WHEN I sign out the app leaving Delete all enabled") {
            accountView.signOutButtonClick()
            alertView.signOutButtonClick()
        }
            
        step("THEN I am on Onboarding landing view") {
            XCTAssertTrue(onboardingView.waitForLandingViewToLoad())
        }
        
        step("THEN the previously added notes are removed") {
            onboardingView.signUpLater()
                            .clickSkipButton()
                            .waitForJournalViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            waitForCountValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 4, elementQuery: allNotes.getNotesNamesElementQuery())

            let currentTestTable = AllNotesTestTable()
            XCTAssertEqual(currentTestTable.numberOfVisibleItems, defaultNotes.numberOfVisibleItems)
            
            let tablesContainingResult = AllNotesTestTable().containsRows(defaultNotes.rows)
            XCTAssertTrue(tablesContainingResult.0, tablesContainingResult.1)
        }

    }
    
    func testSignOutWithoutDeletion() {
        var tableBeforeSignOut: AllNotesTestTable!
        
        step("GIVEN I get the All Notes table content") {
            uiMenu.create10Notes()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            tableBeforeSignOut = AllNotesTestTable()
        }
        
        step("WHEN I Sign out button disabling deletion of notes checkbox") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .account)
            accountView.signOutButtonClick()
            alertView.getDeleteAllCheckbox().tapInTheMiddle()
            alertView.signOutButtonClick()
        }
        
        step("THEN I'm successfully signed out") {
            XCTAssertTrue(accountView.getConnectToBeamButtonElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("THEN notes still exists") {
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(accountView.getConnectToBeamButtonElement())
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            let tablesComparisonResult = AllNotesTestTable().isEqualTo(tableBeforeSignOut)
            XCTAssertTrue(tablesComparisonResult.0, tablesComparisonResult.1)
        }
    }
    
}
