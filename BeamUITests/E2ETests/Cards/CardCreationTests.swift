//
//  CardCreation.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class CardCreationTests: BaseTest {
    
    let cardNameToBeCreated = "CardCreation"
    
    func testCreateCardFromAllCards() {
        let journalView = launchApp()
        
        print("Given I get number of cards in All Cards view")
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue,    journalView.staticText(JournalViewLocators.Buttons.allCardsMenuButton.accessibilityIdentifier))
        let numberOfCardsBeforeAdding = journalView.openAllCardsMenu().getNumberOfCards()
        
        print("When I create a card from All Cards view")
        let allCardsView = AllCardsTestView().addNewCard(cardNameToBeCreated)
        var timeout = 5 //temp solution while looking for an elegant way to wait
        repeat {
            if numberOfCardsBeforeAdding != allCardsView.getNumberOfCards() {
                return
            }
            sleep(1)
            timeout-=1
        } while timeout > 0
        
        print("Then number of cards is increased to +1 in All Cards list")
        XCTAssertEqual(numberOfCardsBeforeAdding + 1, allCardsView.getNumberOfCards())
    }
    
    func testCreateCardUsingCardsSearchList() throws {
        try XCTSkipIf(true, "Temp solution to fix the false failure to be found for Google pop-up window")
        let journalView = launchApp()
        
        print("When I create \(cardNameToBeCreated) a card from Webview cards search results")
        let webView = journalView.searchInOmniBar(cardNameToBeCreated, true)
        webView.searchForCardByTitle(cardNameToBeCreated)
        OmniBarTestView().navigateToJournalViaHomeButton()
        let allCardsMenu = journalView.openAllCardsMenu()
        
        print("Then card with \(cardNameToBeCreated) name appears in All cards menu list")
        XCTAssertTrue(allCardsMenu.isCardNameAvailable(cardNameToBeCreated))
    }
    
    func testCreateCardUsingCardReference() {
        let journalView = launchApp()
        
        print("When I create \(cardNameToBeCreated) a card referencing it from another Card")
        journalView.textView(CardViewLocators.TextFields.noteField.accessibilityIdentifier).firstMatch.click()
        journalView.app.typeText("@" + cardNameToBeCreated)
        journalView.typeKeyboardKey(.enter)
        let allCardsMenu = journalView.openAllCardsMenu()
        
        print("Then card with \(cardNameToBeCreated) name appears in All cards menu list")
        XCTAssertTrue(allCardsMenu.isCardNameAvailable(cardNameToBeCreated))
    }
    
    func testCreateCardOmniboxSearch() {
        let journalView = launchApp()
        
        print("When I create \(cardNameToBeCreated) a card from Omnibar search results")
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Then card with \(cardNameToBeCreated) appears is opened ")
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertTrue(cardView.staticText(cardNameToBeCreated).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
}
