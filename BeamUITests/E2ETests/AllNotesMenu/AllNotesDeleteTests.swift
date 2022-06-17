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
    
    func testDeleteAllNotes() {
        step ("Given I create 2 notes"){
            launchApp()
            uiMenu.createNote()
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
        let indexOfNote = 1
        
        var notesBeforeDeletion: Int!
        
        step ("Given I create 2 notes") {
            launchApp()
            uiMenu.createNote()
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
        let indexOfNote = 0
        var noteName : String!
        var notesBeforeDeletion: Int!
        
        step ("Given I create a note") {
            launchApp()
            uiMenu.createNote()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
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
