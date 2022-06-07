//
//  CardCreation.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

class NoteCreationTests: BaseTest {
    
    let cardNameToBeCreated = "CardCreation"
    var cardView: NoteTestView!
    
    func testCreateCardFromAllCards() {
        let journalView = launchApp()
        
        step("Given I get number of cards in All Notes view"){
            waitFor(PredicateFormat.isHittable.rawValue,    journalView.button(ToolbarLocators.Buttons.noteSwitcherAllCards.accessibilityIdentifier))
        }
        let numberOfCardsBeforeAdding = journalView.openAllNotesMenu().getNumberOfNotes()
        var allCardsView: AllNotesTestView?
        step("When I create a card from All Notes view"){
            allCardsView = AllNotesTestView().addNewNote(cardNameToBeCreated)
            var timeout = 5 //temp solution while looking for an elegant way to wait
            repeat {
                if numberOfCardsBeforeAdding != allCardsView!.getNumberOfNotes() {
                    return
                }
                sleep(1)
                timeout-=1
            } while timeout > 0
        }

        step("Then number of notes is increased to +1 in All Notes list"){
            XCTAssertEqual(numberOfCardsBeforeAdding + 1, allCardsView!.getNumberOfNotes())
        }
    }
    
    func SKIPtestCreateCardUsingCardsSearchList() throws {
        try XCTSkipIf(true, "Destination Note Picker UI is currently hidden")
        let journalView = launchApp()
        step("When I create \(cardNameToBeCreated) a note from Webview cards search results"){
            let webView = journalView.searchInOmniBox(cardNameToBeCreated, true)
            webView.searchForNoteByTitle(cardNameToBeCreated)
            XCTAssertTrue(waitForStringValueEqual(cardNameToBeCreated, webView.getDestinationNoteElement()), "Destination note is not \(cardNameToBeCreated), but \(String(describing: webView.getDestinationNoteElement().value))")
            cardView = webView.openDestinationNote()
            
        }

        step("Then note with \(cardNameToBeCreated) is opened"){
            XCTAssertTrue(cardView.waitForCardViewToLoad())
            XCTAssertTrue(cardView.textField(cardNameToBeCreated).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
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
            let allCardsMenu = journalView.openAllNotesMenu()
            XCTAssertTrue(allCardsMenu.isNoteNameAvailable(cardNameToBeCreated))
        }
    }
    
    func testCreateCardOmniboxSearch() {
        let journalView = launchApp()
        
        step("When I create \(cardNameToBeCreated) a note from Omnibox search results"){
            cardView = journalView.createNoteViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("Then note with \(cardNameToBeCreated) is opened"){
            XCTAssertTrue(cardView.waitForCardViewToLoad())
            XCTAssertEqual(cardView.getCardTitle(), cardNameToBeCreated)
        }

        step("Then Journal has no mentions for created note"){
            ShortcutsHelper().shortcutActionInvoke(action: .showJournal)
            journalView.waitForJournalViewToLoad()
            XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 2)
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString )
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
            cardView = NoteTestView()
            XCTAssertTrue(cardView.waitForCardViewToLoad())
            XCTAssertEqual(cardView.getCardTitle(), cardNameToBeCreated)
        }

    }
    
    func testCreateNoteViewIcon() {
        launchApp()
        cardView = NoteTestView()
        
        step("When I click New note icon") {
            cardView.clickNewNoteCreationButton().getOmniBoxSearchField().typeText(cardNameToBeCreated)
            cardView.typeKeyboardKey(.enter)
        }
        
        step("Then I can sucessfully create a note") {
            XCTAssertTrue(cardView.waitForCardViewToLoad())
            XCTAssertEqual(cardView.getCardTitle(), cardNameToBeCreated)
        }
    }
    
}
