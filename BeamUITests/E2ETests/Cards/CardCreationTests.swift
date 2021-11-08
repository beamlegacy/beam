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
        
        testRailPrint("Given I get number of cards in All Cards view")
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue,    journalView.staticText(JournalViewLocators.Buttons.allCardsMenuButton.accessibilityIdentifier))
        let numberOfCardsBeforeAdding = journalView.openAllCardsMenu().getNumberOfCards()
        
        testRailPrint("When I create a card from All Cards view")
        let allCardsView = AllCardsTestView().addNewCard(cardNameToBeCreated)
        var timeout = 5 //temp solution while looking for an elegant way to wait
        repeat {
            if numberOfCardsBeforeAdding != allCardsView.getNumberOfCards() {
                return
            }
            sleep(1)
            timeout-=1
        } while timeout > 0
        
        testRailPrint("Then number of cards is increased to +1 in All Cards list")
        XCTAssertEqual(numberOfCardsBeforeAdding + 1, allCardsView.getNumberOfCards())
    }
    
    func testCreateCardUsingCardsSearchList() throws {
        let journalView = launchApp()
        
        testRailPrint("When I create \(cardNameToBeCreated) a card from Webview cards search results")
        let webView = journalView.searchInOmniBar(cardNameToBeCreated, true)
        webView.searchForCardByTitle(cardNameToBeCreated)
        XCTAssertTrue(WaitHelper().waitForStringValueEqual(cardNameToBeCreated, webView.getDestinationCardElement()), "Destination card is not \(cardNameToBeCreated), but \(String(describing: webView.getDestinationCardElement().value))")
        let cardView = webView.openDestinationCard()
        
        testRailPrint("Then card with \(cardNameToBeCreated) is opened")
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertTrue(cardView.staticText(cardNameToBeCreated).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testCreateCardUsingCardReference() {
        let journalView = launchApp()
        
        testRailPrint("When I create \(cardNameToBeCreated) a card referencing it from another Card")
        journalView.textView(CardViewLocators.TextFields.noteField.accessibilityIdentifier).firstMatch.click()
        journalView.app.typeText("@" + cardNameToBeCreated)
        journalView.typeKeyboardKey(.enter)
        let allCardsMenu = journalView.openAllCardsMenu()
        
        testRailPrint("Then card with \(cardNameToBeCreated) name appears in All cards menu list")
        XCTAssertTrue(allCardsMenu.isCardNameAvailable(cardNameToBeCreated))
    }
    
    func testCreateCardOmniboxSearch() {
        let journalView = launchApp()
        
        testRailPrint("When I create \(cardNameToBeCreated) a card from Omnibar search results")
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("Then card with \(cardNameToBeCreated) is opened")
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertTrue(cardView.staticText(cardNameToBeCreated).waitForExistence(timeout: minimumWaitTimeout))
    }
    
    func testCreateCardOmniboxCmdEnter() {
        let journalView = launchApp()
        
        testRailPrint("When I create \(cardNameToBeCreated) a card from Omnibar search results via CMD+Enter")
        journalView.searchInOmniBar(cardNameToBeCreated, false)
        _ = journalView.app.otherElements.matching(NSPredicate(format: "identifier CONTAINS '\(WebViewLocators.Other.autocompleteResult.accessibilityIdentifier)'")).firstMatch.waitForExistence(timeout: implicitWaitTimeout)
        journalView.app.typeKey("\r", modifierFlags: .command)
        
        testRailPrint("Then card with \(cardNameToBeCreated) is opened")
        let cardView = CardTestView()
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertTrue(cardView.staticText(cardNameToBeCreated).waitForExistence(timeout: implicitWaitTimeout))
    }
}
