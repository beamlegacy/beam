//
//  SyncTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 07.06.2022.
//

import Foundation
import XCTest

class SyncTests: BaseTest {

    var helper: BeamUITestsHelper!
    
    func testMergeNotesForNewlyCreatedAccount() {
        var notesBeforeSync: AllNotesTestTable!
        
        step("GIVEN I setup staging environment") {
            helper = BeamUITestsHelper(setupStaging().app)
        }
        
        step("WHEN I start using app without being signed in") {
            XCTAssertTrue(OnboardingLandingTestView().waitForLandingViewToLoad(), "Onboarding view wasn't loaded")
            OnboardingLandingTestView().signUpLater().clickSkipButton()
            helper.tapCommand(.create10Notes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            notesBeforeSync = AllNotesTestTable()
        }
        
        step("WHEN close the app and I sign up with a new account") {
            uiMenu.signUpWithRandomTestAccount()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
        
        step("THEN the notes are merged correctly for the newly created account") {
            let notesAfterSync = AllNotesTestTable()
            let syncResult = notesAfterSync.isEqualTo(notesBeforeSync)
            XCTAssertTrue(syncResult.0, syncResult.1)
        }
    }
    
    //Other tests so far are blocked by https://linear.app/beamapp/issue/BE-4342/randomly-created-account-is-displayed-as-not-signed-in
    
}
