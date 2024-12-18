//
//  AllNotesDeleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllNotesDeleteTests: BaseTest {
    
    var allNotesView = AllNotesTestView()
    var journalView: JournalTestView!
    
    let indexOfNote = 0
    
    override func setUp() {
        step("Given I create a note and switch to All Notes") {
            super.setUp()
            uiMenu.invoke(.createNote)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView.waitForAllNotesViewToLoad()
            XCTAssertTrue(allNotesView.getNumberOfNotes() == 5)
        }
    }
    
    func testDeleteAllNotes() {
        testrailId("C963")

        step ("Then I successfully delete all notes"){
            allNotesView.deleteAllNotes()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 1) // Today's note will still be there
        }
    }
    
    func testDeleteSingleNote() throws {
        testrailId("C716")

        step ("Then I successfully delete a note at \(indexOfNote) index"){
            let noteName = allNotesView.getNoteNameValueByIndex(indexOfNote)
            allNotesView
                .openMenuForSingleNote(indexOfNote)
                .selectActionInMenu(.deleteNotes)
            AlertTestView().confirmDeletion()

            XCTAssertEqual(allNotesView.getNumberOfNotes(), 4)
            XCTAssertFalse(allNotesView.isNoteNameAvailable(noteName))
        }

    }
    
    func testUndoDeleteNoteAction() throws {
        testrailId("C716")
        var noteName : String!
        
        testrailId("C527")
        step ("When I delete created note from All Notes view and undo it") {
            noteName = allNotesView.getNoteNameValueByIndex(indexOfNote)
            allNotesView.deleteNoteByIndex(indexOfNote)
            shortcutHelper.shortcutActionInvoke(action: .undo)
        }
        
        step ("Then deleted note appears in the list again") {
            allNotesView.waitForAllNotesViewToLoad()
            allNotesView.waitForNoteTitlesToAppear()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 5)
            XCTAssertTrue(allNotesView.isNoteNameAvailable(noteName))
        }
    }
}
