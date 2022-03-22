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
    var cardView: CardTestView?
    
    func testCreateCardFromAllCards() {
        let journalView = launchApp()
        
        step("Given I get number of cards in All Notes view"){
            waitFor(PredicateFormat.isHittable.rawValue,    journalView.button(ToolbarLocators.Buttons.cardSwitcherAllCards.accessibilityIdentifier))
        }
        let numberOfCardsBeforeAdding = journalView.openAllCardsMenu().getNumberOfCards()
        var allCardsView: AllCardsTestView?
        step("When I create a card from All Notes view"){
            allCardsView = AllCardsTestView().addNewCard(cardNameToBeCreated)
            var timeout = 5 //temp solution while looking for an elegant way to wait
            repeat {
                if numberOfCardsBeforeAdding != allCardsView!.getNumberOfCards() {
                    return
                }
                sleep(1)
                timeout-=1
            } while timeout > 0
        }

        step("Then number of notes is increased to +1 in All Notes list"){
            XCTAssertEqual(numberOfCardsBeforeAdding + 1, allCardsView!.getNumberOfCards())
        }
    }
    
    func SKIPtestCreateCardUsingCardsSearchList() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("When I create \(cardNameToBeCreated) a note from Webview cards search results"){
            let webView = journalView.searchInOmniBox(cardNameToBeCreated, true)
            webView.searchForCardByTitle(cardNameToBeCreated)
            XCTAssertTrue(waitForStringValueEqual(cardNameToBeCreated, webView.getDestinationCardElement()), "Destination note is not \(cardNameToBeCreated), but \(String(describing: webView.getDestinationCardElement().value))")
            cardView = webView.openDestinationCard()
            
        }

        step("Then note with \(cardNameToBeCreated) is opened"){
            XCTAssertTrue(cardView!.waitForCardViewToLoad())
            XCTAssertTrue(cardView!.textField(cardNameToBeCreated).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

    }
    
    func testCreateCardUsingCardReference() {
        let journalView = launchApp()
        
        step("When I create \(cardNameToBeCreated) a note referencing it from another Note"){
            journalView.textView(CardViewLocators.TextFields.textNode.accessibilityIdentifier).firstMatch.click()
            journalView.app.typeText("@" + cardNameToBeCreated)
            journalView.typeKeyboardKey(.enter)
        }

        step("Then note with \(cardNameToBeCreated) name appears in All notes menu list"){
            let allCardsMenu = journalView.openAllCardsMenu()
            XCTAssertTrue(allCardsMenu.isCardNameAvailable(cardNameToBeCreated))
        }
    }
    
    func testCreateCardOmniboxSearch() {
        let journalView = launchApp()
        
        step("When I create \(cardNameToBeCreated) a note from Omnibox search results"){
            cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("Then note with \(cardNameToBeCreated) is opened"){
            XCTAssertTrue(cardView!.waitForCardViewToLoad())
            XCTAssertTrue(cardView!.textField(cardNameToBeCreated).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step("Then Journal has no mentions for created note"){
            ShortcutsHelper().shortcutActionInvoke(action: .showJournal)
            journalView.waitForJournalViewToLoad()
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 1)
            XCTAssertEqual(cardView!.getCardNoteValueByIndex(0), emptyString )
        }

    }
    
    func testCreateCardOmniboxOptionEnter() {
        let journalView = launchApp()
        
        step("When I create \(cardNameToBeCreated) a note from Omnibox search results via Option+Enter"){
            journalView.searchInOmniBox(cardNameToBeCreated, false)
            _ = journalView.app.otherElements.matching(NSPredicate(format: "identifier CONTAINS '\(WebViewLocators.Other.autocompleteResult.accessibilityIdentifier)'")).firstMatch.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
            journalView.app.typeKey("\r", modifierFlags: .option)
        }

        step("Then note with \(cardNameToBeCreated) is opened"){
            cardView = CardTestView()
            XCTAssertTrue(cardView!.waitForCardViewToLoad())
            XCTAssertTrue(cardView!.textField(cardNameToBeCreated).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

    }
}
