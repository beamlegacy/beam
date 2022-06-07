//
//  TodayNoteTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 01/06/2022.
//

import Foundation
import XCTest

class TodayNoteTests: BaseTest {
    
    let shortcuts = ShortcutsHelper()
    let allNotesView = AllNotesTestView()
    let noteTestView = NoteTestView()
    
    func testCannotDeleteTodayNoteInAllNote() {
        step ("Given I navigate to All Note") {
            launchApp()
            shortcuts.shortcutActionInvoke(action: .showAllNotes)
        }
        
        step ("Then I cannot delete Today Note from All Notes") {
            
            allNotesView.openMenuForSingleNote(0)
            XCTAssertFalse(allNotesView.isElementAvailableInSingleNoteMenu(AllNotesViewLocators.MenuItems.deleteNotes))
            allNotesView.typeKeyboardKey(.escape) // close the menu
        }
        
        step ("And I cannot delete Today Note from note view") {
            allNotesView.openFirstNote()
            XCTAssertFalse(noteTestView.getDeleteNoteButton().isEnabled)
        }
    }
    
    func testCannotDeleteTodayNoteDeletingAll() throws {
        try XCTSkipIf(true, "to activate once https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note is fixed")
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        
        step ("Given I navigate to All Note") {
            shortcuts.shortcutActionInvoke(action: .showAllNotes)
            helper.tapCommand(.create10Notes)
        }
        
        step ("Then I cannot delete Today Note from All Notes") {
            allNotesView.deleteAllNotes()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 1)
            XCTAssertEqual(allNotesView.getNoteNameValueByIndex(0), DateHelper().getTodaysDateString(.noteViewTitle))
        }

    }
}
