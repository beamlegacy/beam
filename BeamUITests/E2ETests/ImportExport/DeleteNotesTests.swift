//
//  DeleteNotesTests.swift
//  BeamUITests
//
//  Created by Andrii on 06/12/2021.
//

import Foundation
import XCTest

class DeleteNotesTests: BaseTest {
    
    let alert = AlertTestView()
    let fileMenu = FileMenu()
    let allNotes = AllNotesTestView()
    
    func testDeleteAllLocalContents() {
        //Tests only notes deletion
        runDeleteNoteTest(isLocalContentsTest: true)
    }
    
    func testDeleteAllNotes() {
        //Tests only notes deletion, remote deletion assertion to be investigated if that is possible using Vinyls
        runDeleteNoteTest(isLocalContentsTest: false)
    }
    
    private func runDeleteNoteTest(isLocalContentsTest: Bool) {
        let expectedNumberOfNotesAfterPopulatingDB = 11
        let expectedNumberOfNotesAfterClearingDB = 1
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        step("Given I populate the app with random notes"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.openFirstNote()
            helper.tapCommand(.insertTextInCurrentNote)
            helper.tapCommand(.create10Notes)
        }
        
        step("When I open All notes"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
        
        step("Then there is \(expectedNumberOfNotesAfterPopulatingDB) notes"){
            XCTAssertTrue(allNotes.getNumberOfNotes() > expectedNumberOfNotesAfterClearingDB, "Error occurred when populating the DB")
        }
        
        step("When I click clear notes option"){
            isLocalContentsTest ? fileMenu.deleteAllLocalContents() : fileMenu.deleteAllNotes()
        }
        
        step("Then notes are cleared"){
            launchApp()
            XCTAssertEqual(NoteTestView().getNumberOfVisibleNotes(), 1, "Local data hasn't been cleared")
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            XCTAssertEqual(allNotes.getNumberOfNotes(), expectedNumberOfNotesAfterClearingDB, "Local data hasn't been cleared")
        }
    }
}
