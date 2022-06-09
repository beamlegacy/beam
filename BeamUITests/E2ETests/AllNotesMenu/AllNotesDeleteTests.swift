//
//  AllNotesDeleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllNotesDeleteTests: BaseTest {
    
    let noteName1 = "Note All 1"
    let noteName2 = "Note All 2"
    var allNotesView = AllNotesTestView()
    var journalView: JournalTestView!
    
    func testDeleteAllNotes() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        
        step ("Given I create 2 notes"){
            journalView.createNoteViaOmniboxSearch(noteName1)
            journalView.createNoteViaOmniboxSearch(noteName2)
                .shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            //Workaround for a random issue where Today's note duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            XCTAssertTrue(allNotesView.getNumberOfNotes() >= 3)
        }

        step ("Then I successfully delete all notes"){
            allNotesView.deleteAllNotes()
            XCTAssertEqual(allNotesView.getNumberOfNotes(), 1) // Today's note will still be there
        }

    }
    
    func testDeleteSingleNote() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        let indexOfNote = 1
        
        var notesBeforeDeletion: Int!
        
        step ("Given I create 2 notes") {
            journalView.createNoteViaOmniboxSearch(noteName1)
            journalView.createNoteViaOmniboxSearch(noteName2)
                .shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            //Workaround for a random issue where Today's note duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            notesBeforeDeletion = allNotesView.getNumberOfNotes()
            XCTAssertTrue(notesBeforeDeletion >= 3)
        }

        step ("Then I successfully delete all notes"){
            let noteName = allNotesView.getNoteNameValueByIndex(indexOfNote)
            allNotesView.deleteNoteByIndex(indexOfNote)
            XCTAssertEqual(allNotesView.getNumberOfNotes(), notesBeforeDeletion - 1)
            XCTAssertFalse(allNotesView.isNoteNameAvailable(noteName))
        }

    }
    
    func testUndoDeleteNoteAction() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        let indexOfNote = 0
        var noteName : String!
        var notesBeforeDeletion: Int!
        
        step ("Given I create a note") {
            journalView.createNoteViaOmniboxSearch(noteName1)
                .shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            notesBeforeDeletion = allNotesView.getNumberOfNotes()
        }
        
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
