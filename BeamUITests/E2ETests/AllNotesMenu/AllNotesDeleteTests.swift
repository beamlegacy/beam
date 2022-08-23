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
    
    override func setUp() {
        step("GIVEN I launch app and create a note") {
            launchApp()
            uiMenu.createNote()
        }
    }
    
    func testDeleteAllNotes() {
        testrailId("C963")
        step ("Given I create a note and switch to All Notes"){
            uiMenu.createNote()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            XCTAssertTrue(allNotesView.getNumberOfNotes() == 3)
        }

        step ("Then I successfully delete all notes"){
            allNotesView.deleteAllNotes()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 1) // Today's note will still be there
        }
    }
    
    func testDeleteSingleNote() throws {
        testrailId("C716")
        let indexOfNote = 1
        
        var notesBeforeDeletion: Int!
        
        step ("Given I create a note and switch to All Notes"){
            uiMenu.createNote()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            notesBeforeDeletion = allNotesView.getNumberOfNotes()
            XCTAssertTrue(notesBeforeDeletion == 3)
        }

        step ("Then I successfully delete a note at \(indexOfNote) index"){
            let noteName = allNotesView.getNoteNameValueByIndex(indexOfNote)
            allNotesView
                .openMenuForSingleNote(indexOfNote)
                .selectActionInMenu(.deleteNotes)
            AlertTestView().confirmDeletion()

            XCTAssertEqual(allNotesView.getNumberOfNotes(), notesBeforeDeletion - 1)
            XCTAssertFalse(allNotesView.isNoteNameAvailable(noteName))
        }

    }
    
    func testUndoDeleteNoteAction() throws {
        testrailId("C716")
        let indexOfNote = 0
        var noteName : String!
        var notesBeforeDeletion: Int!
        
        step ("Given I switch to All Notes") {
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            notesBeforeDeletion = allNotesView.getNumberOfNotes()
        }
        
        testrailId("C527")
        step ("When I delete created note from All Notes view and undo it") {
            noteName = allNotesView.getNoteNameValueByIndex(indexOfNote)
            allNotesView.deleteNoteByIndex(indexOfNote)
            shortcutHelper.shortcutActionInvoke(action: .undo)
        }
        
        step ("Then deleted note appears in the list again") {
            allNotesView.waitForAllNotesViewToLoad()
            allNotesView.waitForNoteTitlesToAppear()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), notesBeforeDeletion)
            XCTAssertTrue(allNotesView.isNoteNameAvailable(noteName))
        }
    }
}
