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
        
        testRailPrint("Given I populate the app with random notes")
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        allCards.openFirstCard()
        helper.tapCommand(.insertTextInCurrentNote)
        helper.tapCommand(.create10Notes)
        
        testRailPrint("When Open All cards - asssert it is \(expectedNumberOfCardsAfterPopulatingDB) cards")
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        XCTAssertEqual(allCards.getNumberOfCards(), expectedNumberOfCardsAfterPopulatingDB, "Error occurred when populating the DB")
        
        testRailPrint("When click clear notes option")
        isLocalContentsTest ? fileMenu.deleteAllLocalContents() : fileMenu.deleteAllNotes()
        XCTAssertTrue(alert.getAlertDialog().staticTexts["All the local data has been deleted. Beam must exit now."].waitForExistence(timeout: implicitWaitTimeout))
        alert.exitNowClick()
        
        testRailPrint("Then notes are cleared")
        launchApp()
        XCTAssertEqual(CardTestView().getNumberOfVisibleNotes(), 1, "Local data hasn't been cleared")
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        XCTAssertEqual(allCards.getNumberOfCards(), expectedNumberOfCardsAfterClearingDB, "Local data hasn't been cleared")
    }
}
