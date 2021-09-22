//
//  AllCardsDeleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllCardsDeleteTests: BaseTest {
    
    let cardName1 = "Card All 1"
    let cardName2 = "Card All 2"
    
    func testDeleteAllCards() {
        let journalView = launchApp()
        
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        journalView.createCardViaOmnibarSearch(cardName2)
        let allCardsView = OmniBarTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
        XCTAssertEqual(allCardsView.getNumberOfCards(), 3)
        
        testRailPrint("Then I successfully delete all cards")
        allCardsView.deleteAllCards()
        XCTAssertEqual(allCardsView.getNumberOfCards(), 0)
    }
    
    func testDeleteSingleCard() {
        let journalView = launchApp()
        let indexOfCard = 1
        testRailPrint("Given I create 2 cards")
        journalView.createCardViaOmnibarSearch(cardName1)
        journalView.createCardViaOmnibarSearch(cardName2)
        let allCardsView = OmniBarTestView().navigateToJournalViaHomeButton().openAllCardsMenu()
        XCTAssertEqual(allCardsView.getNumberOfCards(), 3)
        
        let cardName = allCardsView.getCardNameValueByIndex(indexOfCard)
        testRailPrint("Then I successfully delete all cards")
        allCardsView.deleteCardByIndex(indexOfCard)
        XCTAssertEqual(allCardsView.getNumberOfCards(), 2)
        XCTAssertFalse(allCardsView.isCardNameAvailable(cardName))
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
