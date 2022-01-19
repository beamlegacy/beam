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
    
    func testDeleteAllCards() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let journalView = self.restartApp()
        
        testRailPrint("Given I create 2 notes")
        journalView.createCardViaOmniboxSearch(cardName1)
        journalView.createCardViaOmniboxSearch(cardName2)
        let allCardsView = OmniBoxTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
        //Workaround for a random issue where Today's card duplicates are created
        //main thing is to make sure there are some multiple notes available for deletion
        XCTAssertTrue(allCardsView.getNumberOfCards() >= 3)
        
        testRailPrint("Then I successfully delete all notes")
        allCardsView.deleteAllCards()
        XCTAssertEqual(allCardsView.getNumberOfCards(), 0)
    }
    
    func testDeleteSingleCard() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let journalView = self.restartApp()
        
        let indexOfCard = 1
        testRailPrint("Given I create 2 notes")
        journalView.createCardViaOmniboxSearch(cardName1)
        journalView.createCardViaOmniboxSearch(cardName2)
        let allCardsView = OmniBoxTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
        //Workaround for a random issue where Today's card duplicates are created
        //main thing is to make sure there are some multiple notes available for deletion
        let cardsBeforeDeletion = allCardsView.getNumberOfCards()
        XCTAssertTrue(cardsBeforeDeletion >= 3)
        
        let cardName = allCardsView.getCardNameValueByIndex(indexOfCard)
        testRailPrint("Then I successfully delete all notes")
        allCardsView.deleteCardByIndex(indexOfCard)
        XCTAssertEqual(allCardsView.getNumberOfCards(), cardsBeforeDeletion - 1)
        XCTAssertFalse(allCardsView.isCardNameAvailable(cardName))
    }
}
