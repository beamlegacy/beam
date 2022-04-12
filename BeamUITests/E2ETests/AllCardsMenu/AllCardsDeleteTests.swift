//
//  AllCardsDeleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllCardsDeleteTests: BaseTest {
    
    let cardName1 = "Note All 1"
    let cardName2 = "Note All 2"
    var allCardsView: AllCardsTestView?
    
    func testDeleteAllCards() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let journalView = self.restartApp()
        
        step ("Given I create 2 notes"){
            journalView.createCardViaOmniboxSearch(cardName1)
            journalView.createCardViaOmniboxSearch(cardName2)
            allCardsView = OmniBoxTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
            //Workaround for a random issue where Today's card duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            XCTAssertTrue(allCardsView!.getNumberOfCards() >= 3)
        }

        step ("Then I successfully delete all notes"){
            allCardsView!.deleteAllCards()
            XCTAssertEqual(allCardsView!.getNumberOfCards(), 1) // Today's note will still be there
        }

    }
    
    func testDeleteSingleCard() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let journalView = self.restartApp()
        let indexOfCard = 1
        
        var cardsBeforeDeletion: Int?
        
        step ("Given I create 2 notes"){
            journalView.createCardViaOmniboxSearch(cardName1)
            journalView.createCardViaOmniboxSearch(cardName2)
            allCardsView = OmniBoxTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
            //Workaround for a random issue where Today's card duplicates are created
            //main thing is to make sure there are some multiple notes available for deletion
            cardsBeforeDeletion = allCardsView!.getNumberOfCards()
            XCTAssertTrue(cardsBeforeDeletion! >= 3)
        }

        step ("Then I successfully delete all notes"){
            let cardName = allCardsView!.getCardNameValueByIndex(indexOfCard)
            allCardsView!.deleteCardByIndex(indexOfCard)
            XCTAssertEqual(allCardsView!.getNumberOfCards(), cardsBeforeDeletion! - 1)
            XCTAssertFalse(allCardsView!.isCardNameAvailable(cardName))
        }

    }
    
    func testUndoDeleteCardAction() {
        
        let journalView = launchApp()
        allCardsView = AllCardsTestView()
        let indexOfCard = 0
        var cardName : String?
        var cardsBeforeDeletion: Int?
        
        step ("Given I create a note") {
            journalView.createCardViaOmniboxSearch(cardName1)
            ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
            cardsBeforeDeletion = allCardsView!.getNumberOfCards()
        }
        
        step ("When I delete created note from All Cards view and undo it") {
            cardName = allCardsView!.getCardNameValueByIndex(indexOfCard)
            allCardsView!.deleteCardByIndex(indexOfCard)
            ShortcutsHelper().shortcutActionInvoke(action: .undo)
        }
        
        step ("Then deleted note appears in the list again") {
            allCardsView!.waitForAllCardsViewToLoad()
            allCardsView!.waitForCardTitlesToAppear()
            XCTAssertEqual(allCardsView!.getNumberOfCards(), cardsBeforeDeletion!)
            XCTAssertTrue(allCardsView!.isCardNameAvailable(cardName!))
        }
    }
}
