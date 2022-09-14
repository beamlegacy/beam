//
//  SyncTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 07.06.2022.
//

import Foundation
import XCTest

class SyncTests: BaseTest {
    
    func testMergeNotesForNewlyCreatedAccount() {
        testrailId("C1158")
        var notesBeforeSync: AllNotesTestTable!
        let allNotes = AllNotesTestView()
        
        step("GIVEN I start using app without being signed in") {
            uiMenu.invoke(.showOnboarding)
            XCTAssertTrue(OnboardingLandingTestView().waitForLandingViewToLoad(), "Onboarding view wasn't loaded")
            OnboardingLandingTestView()
                .signUpLater()
                .clickSkipButton()
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
    
    //Other tests so far are blocked by https://linear.app/beamapp/issue/BE-4342/randomly-created-account-is-displayed-as-not-signed-in
    
}
