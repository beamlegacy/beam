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
        testrailId("C517")
        //Tests only notes deletion
        runDeleteNoteTest(isLocalContentsTest: true)
    }
    
    func testDeleteAllNotes() {
        testrailId("C516")
        //Tests only notes deletion, remote deletion assertion to be investigated if that is possible using Vinyls
        runDeleteNoteTest(isLocalContentsTest: false)
    }
    
    private func runDeleteNoteTest(isLocalContentsTest: Bool) {
        let expectedNumberOfNotesAfterPopulatingDB = 14
        let expectedNumberOfNotesAfterClearingDB = 4
        step("Given I populate the app with random notes"){
            launchAppAndOpenTodayNote()
            uiMenu.invoke(.insertTextInCurrentNote)
                .invoke(.create10NormalNotes)
        }
        
        step("When I open All notes"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
        }
        
        step("Then there is \(expectedNumberOfNotesAfterPopulatingDB) notes"){
            XCTAssertEqual(allNotes.getNumberOfNotes(), expectedNumberOfNotesAfterPopulatingDB, "Error occurred when populating the DB")
        }
        
        step("When I click clear notes option"){
            isLocalContentsTest ? fileMenu.deleteAllLocalContents() : fileMenu.deleteAllNotes()
        }
        
        step("Then notes are cleared"){
            launchApp()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotes.waitForAllNotesViewToLoad()
            XCTAssertEqual(allNotes.getNumberOfNotes(), expectedNumberOfNotesAfterClearingDB, "Local data hasn't been cleared")
            openTodayNote()
            XCTAssertEqual(NoteTestView().getNumberOfVisibleNodes(), 2, "Local data hasn't been cleared")
        }
    }
}
