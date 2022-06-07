//
//  EditorShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest
import BeamCore

class EditorShortcutsTests: BaseTest {
    
    let helper = ShortcutsHelper()
    let webView = WebTestView()
    var cardView: NoteTestView!
    
    func testInstantSearchFromCard() {
        let searchWord = "Everest"
        
        step ("Given I search for \(searchWord)"){
            launchApp()
            cardView = openFirstNoteInAllNotesList()
            cardView.typeInCardNoteByIndex(noteIndex: 0, text: searchWord)
            helper.shortcutActionInvoke(action: .instantSearch)
        }
        
        step ("Then I see 1 tab opened"){
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
            webView.openDestinationNote()
            XCTAssertTrue(cardView.waitForCardViewToLoad())
        }
        
        step ("Then I see \(searchWord) link as a first note"){
            XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 1)
            let actualNoteValue = cardView.getCardNoteValueByIndex(0)
            XCTAssertTrue(actualNoteValue == searchWord + " - Google Search" ||
                          actualNoteValue == searchWord + " - Recherche Google" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)&client=safari" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)",
                          "Actual note value:\(actualNoteValue)")
            cardView.getCardNoteElementByIndex(0).coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.5)).tap()
        }
        
        step ("Then I'm redirected to a new tab and the card has not been changed"){
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            webView.openDestinationNote()
            XCTAssertTrue(cardView!.waitForCardViewToLoad())
            XCTAssertEqual(cardView!.getNumberOfVisibleNotes(), 1)
            let actualNoteValue = cardView.getCardNoteValueByIndex(0)
            XCTAssertTrue(actualNoteValue == searchWord + " - Google Search" ||
                          actualNoteValue == searchWord + " - Recherche Google" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)&client=safari" ||
                          actualNoteValue == "https://www.google.com/search?q=\(searchWord)")
        }
        
    }
    
    func testSelectAllCopyPasteUndoRedoTextInCard() {
        
        let textToType = "This text replaces selected notes text"
        step ("Then app doesn't crash after using text edit shortcuts on empty note"){
            launchApp()
            cardView = openFirstNoteInAllNotesList()
            helper.shortcutActionInvoke(action: .selectAll)
            helper.shortcutActionInvoke(action: .copy)
            cardView.typeKeyboardKey(.delete)
            helper.shortcutActionInvoke(action: .undo)
            helper.shortcutActionInvoke(action: .redo)
        }
        
        
        BeamUITestsHelper(cardView.app).tapCommand(.insertTextInCurrentNote)
        let firstNoteValue = cardView.getCardNoteValueByIndex(1)
        
        helper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.delete)
        step ("Then deleted 1st note successfully"){
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
        }
        
        step ("Then deleted all notes successfully"){
            helper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            cardView.typeKeyboardKey(.delete)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView!.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString)
            
        }
        
        step ("Then undo deletion successfully"){
            helper.shortcutActionInvoke(action: .undo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
            
        }
        
        step ("Then redo deletion successfully"){
            helper.shortcutActionInvoke(action: .redo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), emptyString)
        }
        
        step ("Then undo redone successfully"){
            helper.shortcutActionInvoke(action: .undo)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
        }
        
        step ("Then replace existing text"){
            cardView.getCardNoteElementByIndex(0).tapInTheMiddle()
            helper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
            cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), textToType)
            
        }
        
        step ("Then copy paste existing text"){
            helper.shortcutActionInvoke(action: .selectAll)
            helper.shortcutActionInvoke(action: .copy)
            cardView.typeKeyboardKey(.rightArrow)
            cardView.typeKeyboardKey(.return)
            cardView.pasteText(textToPaste: textToType)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 2, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
            XCTAssertEqual(cardView.getCardNoteValueByIndex(0), textToType)
            XCTAssertEqual(cardView.getCardNoteValueByIndex(1), textToType)
        }
    }
    
    func SKIPtestSwitchWebToDestinationCard () throws {
        try XCTSkipIf(true, "WIP")
        let card1 = "Destination One"
        let card2 = "Destination Two"
        let testHelper = BeamUITestsHelper(webView.app)
        let journalView = launchApp()
        step ("Given I create \(card1) note"){
            //TBD replace creation by omnibox to craetion by Destination cards search
            webView.searchForNoteByTitle(card1)
            journalView.createNoteViaOmniboxSearch(card1)
        }
        
        step ("When I search in web and switch to card view"){
            journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
            helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        }
        
        step ("Then the destination card is remained \(card1)"){
            XCTAssertEqual(cardView!.getCardTitle(), card1)
        }
        
        step ("Given I create \(card2) note"){
            journalView.createNoteViaOmniboxSearch(card2)
        }
        
        step ("When I search in web and switch to note view"){
            journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
            helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        }
        
        step ("Then the destination card is remained \(card2)"){
            XCTAssertEqual(cardView.getCardTitle(), card2)
        }
        
        step ("Then \(card2) is a destination note in web mode"){
            helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
            XCTAssertEqual(webView.getDestinationNoteTitle(), card2)
        }
        
        step ("Then \(card1) is a destination note in web mode when switching tabs"){
            helper.shortcutActionInvoke(action: .jumpToPreviousTab)
            XCTAssertTrue(waitForStringValueEqual(card1, webView.getDestinationNoteElement(), BaseTest.minimumWaitTimeout))
        }
        
        step ("Then \(card2) is a destination note in web mode when switching tabs"){
            helper.shortcutActionInvoke(action: .jumpToNextTab)
            XCTAssertTrue(waitForStringValueEqual(card2, webView.getDestinationNoteElement(), BaseTest.minimumWaitTimeout))
        }
       
    }
    
    func assertDestinationCard(_ cardName: String) {
        XCTAssertTrue(waitForStringValueEqual(cardName, webView.getDestinationNoteElement()), "Destination note is not \(cardName), but \(String(describing: webView.getDestinationNoteElement().value))")
    }
}
