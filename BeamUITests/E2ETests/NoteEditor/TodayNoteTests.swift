//
//  TodayNoteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 01/06/2022.
//

import Foundation
import XCTest

class TodayNoteTests: BaseTest {
    
    let allNotesView = AllNotesTestView()
    let noteTestView = NoteTestView()
    
    func testCannotDeleteTodayNoteInAllNote() {
        testrailId("C748")
        step ("Given I navigate to All Note") {
            deleteAllNotes() // delete onboarding notes for the test
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView.waitForAllNotesViewToLoad()
        }
        
        step ("Then I cannot delete Today Note from All Notes") {
            allNotesView.openMenuForSingleNote(0)
            XCTAssertFalse(allNotesView.isElementAvailableInSingleNoteMenu(AllNotesViewLocators.MenuItems.deleteNotes))
            allNotesView.typeKeyboardKey(.escape) // close the menu
        }
        
        step ("And I cannot delete Today Note from note view") {
            openTodayNote()
            XCTAssertFalse(noteTestView.getDeleteNoteButton().isEnabled)
        }
    }
    
    func testCannotDeleteTodayNoteDeletingAll() throws {
        testrailId("C748")
        
        step ("Given I navigate to All Note") {
            uiMenu.invoke(.create10Notes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView.waitForAllNotesViewToLoad()
        }
        
        step ("Then I cannot delete Today Note from All Notes") {
            allNotesView.deleteAllNotes()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 1)
            XCTAssertEqual(allNotesView.getNoteNameValueByIndex(0), DateHelper().getTodaysDateString(.noteViewTitle))
        }

    }
}
