//
//  SyncTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 07.06.2022.
//

import Foundation
import XCTest

class SyncTests: BaseTest {

    let accountTestView = AccountTestView()
    let alertTestView = AlertTestView()
    let allNotes = AllNotesTestView()
    
    func testMergeNotesForNewlyCreatedAccount() {
        testrailId("C1158")
        var notesBeforeSync: AllNotesTestTable!
        
        step("GIVEN I start using app without being signed in") {
            uiMenu.invoke(.showOnboarding)
            XCTAssertTrue(OnboardingMinimalTestView().waitForLandingViewToLoad(), "Onboarding view wasn't loaded")
            OnboardingMinimalTestView()
                .continueOnboarding()
                .clickSkipButton()
                .closeTab()
            JournalTestView()
                .waitForJournalViewToLoad()
            uiMenu.invoke(.create10NormalNotes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            notesBeforeSync = AllNotesTestTable()
        }
        
        step("WHEN close the app and I sign up with a new account") {
            restartApp()
            uiMenu.invoke(.signUpWithRandomTestAccount)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
        }
        
        step("THEN the notes are merged correctly for the newly created account") {
            let notesAfterSync = AllNotesTestTable()
            let syncResult = notesAfterSync.isEqualTo(notesBeforeSync)
            XCTAssertTrue(syncResult.0, syncResult.1)
        }
    }
    
    func testSyncCreatedNotes() throws {
        testrailId("C1016")
        var onboardingImportDataTestView: OnboardingImportDataTestView!
        var firstAccountNotes: AllNotesTestTable!
        step("GIVEN I start using app without being signed in") {
            hiddenCommand.deleteAllNotes()
            signUpStagingWithRandomAccount()
        }
        
        step("WHEN I create note with data"){
            uiMenu.invoke(.createNote)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            allNotes.sortTableBy(.title).waitForAllNotesViewToLoad()
            firstAccountNotes = AllNotesTestTable()
        }
        
        let accountInfo = getCredentials() // will also open Preferences > Account

        step("AND I signout deleting all data ") {
            accountTestView.signOutButtonClick()
            alertTestView.signOutButtonClick()
            OnboardingMinimalTestView().waitForLandingViewToLoad()
            OnboardingMinimalTestView().continueOnboarding().clickSkipButton().closeTab()
            hiddenCommand.deleteAllNotes() // delete the new onboarding notes
        }
        
        step("AND I sign in with the same account") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .account)
            accountTestView.connectToBeamButtonClick()
            onboardingImportDataTestView = signInWithoutPkKeyCheck(email: accountInfo!.email, password: accountInfo!.password)
        }
        
        step("THEN I am on Journal view") {
            onboardingImportDataTestView.waitForImportDataViewLoad()
            PreferencesBaseView().close(.account)
            XCTAssertTrue(JournalTestView().waitForJournalViewToLoad().isJournalOpened())
        }
        
        step("AND all data is correctly synchronised"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            allNotes.sortTableBy(.title).waitForAllNotesViewToLoad()
            let comparisonResult = AllNotesTestTable().isEqualTo(firstAccountNotes)
            XCTAssertTrue(comparisonResult.0, comparisonResult.1)
        }
    }
    
    func testSynchroniseDataOnAccountsSwitching() {
        testrailId("C1188")

        let preferencesView = PreferencesBaseView()
        step("GIVEN I setup staging environment creating an account and notes") {
            signUpStagingWithRandomAccount()
            uiMenu.invoke(.create10NormalNotes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
        
        let userOneCredentials = getCredentials()
        
        step("WHEN I sign out deleting all data") {
            accountTestView.signOutButtonClick()
            alertTestView.signOutButtonClick()
        }
        
        step("AND I sign up with a new random account adding more notes") {
            OnboardingLandingTestView().waitForLandingViewToLoad()
            signUpStagingWithRandomAccount()
            uiMenu.invoke(.create10NormalNotes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }

        step("AND I sign out leaving all data") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            preferencesView.navigateTo(preferenceView: .account)
            accountTestView.signOutButtonClick()
            alertTestView.getDeleteAllCheckbox().tapInTheMiddle()
            alertTestView.signOutButtonClick()
        }
        
        step("AND I sign in using first account") {
            XCTAssertTrue(accountTestView.getConnectToBeamButtonElement().waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            accountTestView.connectToBeamButtonClick()
            _ = signInWithoutPkKeyCheck(email: userOneCredentials!.email, password: userOneCredentials!.password)
            XCTAssertTrue(preferencesView.waitForPreferencesToBeDisplayedAfterSync())
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("THEN notes of user1 and user2 are merged as I didn't delete locally"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            XCTAssertEqual(allNotes.getNumberOfNotes(), 24) // we remove the merge of onboarding notes (14 + 14 - 4)
        }
    }
}
