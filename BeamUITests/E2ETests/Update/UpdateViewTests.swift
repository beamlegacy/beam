//
//  UpdateViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 21.09.2021.
//

import Foundation
import XCTest

class UpdateViewTests: BaseTest {

    let journalView = JournalTestView()
    
    func testUpdateViewAppearance() {
        testrailId("C696")
        step ("Given I enable Update for the app"){
            uiMenu.invoke(.setAutoUpdateToMock)
        }
        
        step ("Then I can open and close it. It has required items"){
            let updateView = journalView.clickUpdateNow()
            XCTAssertTrue(updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            updateView.closeUpdateWindow()
            XCTAssertTrue(waitForDoesntExist( updateView.button(UpdateViewLocators.Buttons.updateNowButton.accessibilityIdentifier)))
        }
    }
    
    func testUpdateAvailableEverywhereInNoteView() {
        testrailId("C696")
        step ("Given I enable Update for the app"){
            uiMenu.invoke(.setAutoUpdateToMock)
            XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step ("Then it is visible in note view"){
            XCTAssertTrue(journalView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step ("Then it is visible in All notes view"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            let allNotesView = AllNotesTestView()
            allNotesView.waitForAllNotesViewToLoad()
            XCTAssertTrue(allNotesView.staticText(JournalViewLocators.StaticTexts.updateNowButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
