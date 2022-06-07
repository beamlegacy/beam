//
//  AllCardsDeleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllNotesDeleteTests: BaseTest {
    
    let cardName1 = "Note All 1"
    let cardName2 = "Note All 2"
    var allCardsView = AllNotesTestView()
    var journalView: JournalTestView!
    
    func testDeleteAllCards() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        
        step ("Given I create 2 notes"){
            journalView.createNoteViaOmniboxSearch(cardName1)
            journalView.createNoteViaOmniboxSearch(cardName2)
                .shortcutsHelper.shortcutActionInvoke(action: .showAllNotes)
            //Workaround for a random issue where Today's card duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            XCTAssertTrue(allCardsView.getNumberOfNotes() >= 3)
        }

        step ("Then I successfully delete all notes"){
            allCardsView.deleteAllNotes()
            XCTAssertEqual(allCardsView.getNumberOfNotes(), 1) // Today's note will still be there
        }

    }
    
    func testDeleteSingleCard() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        let indexOfCard = 1
        
        var cardsBeforeDeletion: Int!
        
        step ("Given I create 2 notes") {
            journalView.createNoteViaOmniboxSearch(cardName1)
            journalView.createNoteViaOmniboxSearch(cardName2)
                .shortcutsHelper.shortcutActionInvoke(action: .showAllNotes)
            //Workaround for a random issue where Today's card duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            cardsBeforeDeletion = allCardsView.getNumberOfNotes()
            XCTAssertTrue(cardsBeforeDeletion >= 3)
        }

        step ("Then I successfully delete all notes"){
            let cardName = allCardsView.getNoteNameValueByIndex(indexOfCard)
            allCardsView.deleteNoteByIndex(indexOfCard)
            XCTAssertEqual(allCardsView.getNumberOfNotes(), cardsBeforeDeletion - 1)
            XCTAssertFalse(allCardsView.isNoteNameAvailable(cardName))
        }

    }
    
    func testUndoDeleteCardAction() throws {
        try XCTSkipIf(true, "The test is blocked by https://linear.app/beamapp/issue/BE-4327/distinguish-all-notes-editor-option-for-all-notes-and-single-note")
        journalView = launchApp()
        let indexOfCard = 0
        var cardName : String!
        var cardsBeforeDeletion: Int!
        
        step ("Given I create a note") {
            journalView.createNoteViaOmniboxSearch(cardName1)
                .shortcutsHelper.shortcutActionInvoke(action: .showAllNotes)
            cardsBeforeDeletion = allCardsView.getNumberOfNotes()
        }
        
        step ("When I delete created note from All Cards view and undo it") {
            cardName = allCardsView.getNoteNameValueByIndex(indexOfCard)
            allCardsView.deleteNoteByIndex(indexOfCard)
            ShortcutsHelper().shortcutActionInvoke(action: .undo)
        }
        
        step ("Then deleted note appears in the list again") {
            allCardsView.waitForAllNotesViewToLoad()
            allCardsView.waitForNoteTitlesToAppear()
            XCTAssertEqual(allCardsView.getNumberOfNotes(), cardsBeforeDeletion)
            XCTAssertTrue(allCardsView.isNoteNameAvailable(cardName))
        }
    }
}
