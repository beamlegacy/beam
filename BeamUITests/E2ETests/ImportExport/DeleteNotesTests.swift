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
    let allCards = AllCardsTestView()
    let shortcutsHeleper = ShortcutsHelper()
    
    func testDeleteAllLocalContents() {
        //Tests only notes deletion
        runDeleteNoteTest(isLocalContentsTest: true)
    }
    
    func testDeleteAllNotes() {
        //Tests only notes deletion, remote deletion assertion to be investigated if that is possible using Vinyls
        runDeleteNoteTest(isLocalContentsTest: false)
    }
    
    private func runDeleteNoteTest(isLocalContentsTest: Bool) {
        let expectedNumberOfCardsAfterPopulatingDB = 11
        let expectedNumberOfCardsAfterClearingDB = 1
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        step("Given I populate the app with random notes"){
            ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
            allCards.openFirstCard()
            helper.tapCommand(.insertTextInCurrentNote)
            helper.tapCommand(.create10Notes)
        }
        
        step("When I open All notes"){
            ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        }
        
        step("Then there is \(expectedNumberOfCardsAfterPopulatingDB) notes"){
            XCTAssertTrue(allCards.getNumberOfCards() > expectedNumberOfCardsAfterClearingDB, "Error occurred when populating the DB")
        }
        
        step("When I click clear notes option"){
            isLocalContentsTest ? fileMenu.deleteAllLocalContents() : fileMenu.deleteAllNotes()
        }
        
        step("Then notes are cleared"){
            launchApp()
            XCTAssertEqual(CardTestView().getNumberOfVisibleNotes(), 1, "Local data hasn't been cleared")
            ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
            XCTAssertEqual(allCards.getNumberOfCards(), expectedNumberOfCardsAfterClearingDB, "Local data hasn't been cleared")
        }
    }
}
