//
//  EditorShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest

class EditorShortcutsTests: BaseTest {
    
    let helper = ShortcutsHelper()
    let wait = WaitHelper()
    let webView = WebTestView()
    
    func testInstantSearchFromCard() {
        let searchWord = "Everest"
        launchApp()
        
        testRailPrint("Given I search for \(searchWord)")
        let cardView = openFirstCardInAllCardsList()
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: searchWord)
        helper.shortcutActionInvoke(action: .instantSearch)
        
        testRailPrint("Then I see 1 tab opened")
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: implicitWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
        webView.openDestinationCard()
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        
        testRailPrint("Then I see \(searchWord) link as a first note")
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 1)
        XCTAssertTrue(cardView.getCardNoteValueByIndex(0) == searchWord + " - Google Search" ||
                        cardView.getCardNoteValueByIndex(0) == searchWord + " - Recherche Google" || cardView.getCardNoteValueByIndex(0) == "https://www.google.com/search?q=\(searchWord)&client=safari")
        cardView.getCardNoteElementByIndex(0).coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.5)).tap()
        
        testRailPrint("Then I'm redirected to a new tab and the card has not beed changed")
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        webView.openDestinationCard()
        XCTAssertTrue(cardView.waitForCardViewToLoad())
        XCTAssertEqual(cardView.getNumberOfVisibleNotes(), 1)
        // Fails due to https://linear.app/beamapp/issue/BE-2165/cards-hyperlink-title-is-changed-to-url-when-clicking-on-it
        //XCTAssertEqual(cardView.getCardNoteValueByIndex(0), searchWord + " - Google Search")
    }
    
    func testSelectAllCopyPasteUndoRedoTextInCard() {
        launchApp()
        let cardView = openFirstCardInAllCardsList()
        let textToType = "This text replaces selected notes text"
        testRailPrint("Then app doesn't crash after using text edit shortcuts on empty note")
        helper.shortcutActionInvoke(action: .selectAll)
        helper.shortcutActionInvoke(action: .copy)
        cardView.typeKeyboardKey(.delete)
        helper.shortcutActionInvoke(action: .undo)
        helper.shortcutActionInvoke(action: .redo)
        
        BeamUITestsHelper(cardView.app).tapCommand(.insertTextInCurrentNote)
        let firstNoteValue = cardView.getCardNoteValueByIndex(1)
        
        helper.shortcutActionInvoke(action: .selectAll)
        cardView.typeKeyboardKey(.delete)
        testRailPrint("Then deleted 1st note successfully")
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
        
        testRailPrint("Then deleted all notes successfully")
        helper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
        cardView.typeKeyboardKey(.delete)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), "")
        
        testRailPrint("Then undo deletion successfully")
        helper.shortcutActionInvoke(action: .undo)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
        
        testRailPrint("Then redo deletion successfully")
        helper.shortcutActionInvoke(action: .redo)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), "")
        
        testRailPrint("Then undo redone successfully")
        helper.shortcutActionInvoke(action: .undo)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 4, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), firstNoteValue)
        
        testRailPrint("Then replace existing text")
        cardView.getCardNoteElementByIndex(0).tapInTheMiddle()
        helper.shortcutActionInvokeRepeatedly(action: .selectAll, numberOfTimes: 3)
        cardView.typeInCardNoteByIndex(noteIndex: 0, text: textToType)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), textToType)
        
        testRailPrint("Then copy paste existing text")
        helper.shortcutActionInvoke(action: .selectAll)
        helper.shortcutActionInvoke(action: .copy)
        cardView.typeKeyboardKey(.rightArrow)
        cardView.typeKeyboardKey(.return)
        cardView.pasteText(textToPaste: textToType)
        XCTAssertTrue(wait.waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: cardView.getCardNotesElementQueryForVisiblePart()))
        XCTAssertEqual(cardView.getCardNoteValueByIndex(0), textToType)
        XCTAssertEqual(cardView.getCardNoteValueByIndex(1), textToType)
    }
    
    func SKIPtestSwitchWebToDestinationCard () throws {
        try XCTSkipIf(true, "WIP")
        let card1 = "Destination One"
        let card2 = "Destination Two"
        let wait = WaitHelper()
        let testHelper = BeamUITestsHelper(webView.app)
        let journalView = launchApp()
        testRailPrint("Given I create \(card1) note")
        //TBD replace creation by omnibox to craetion by Destination cards search
        webView.searchForCardByTitle(card1)
        journalView.createCardViaOmniboxSearch(card1)
        
        testRailPrint("When I search in web and switch to card view")
        journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
        helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        let cardView = CardTestView()
        testRailPrint("Then the destination card is remained \(card1)")
        XCTAssertEqual(cardView.getCardTitle(), card1)
        
        testRailPrint("Given I create \(card2) note")
        journalView.createCardViaOmniboxSearch(card2)
        
        testRailPrint("When I search in web and switch to note view")
        journalView.searchInOmniBox(testHelper.randomSearchTerm(), true)
        helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        testRailPrint("Then the destination card is remained \(card2)")
        XCTAssertEqual(cardView.getCardTitle(), card2)
        
        testRailPrint("Then \(card2) is a destination note in web mode")
        helper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        XCTAssertEqual(webView.getDestinationCardTitle(), card2)
        
        testRailPrint("Then \(card1) is a destination note in web mode when switching tabs")
        helper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(wait.waitForStringValueEqual(card1, webView.getDestinationCardElement(), minimumWaitTimeout))
        
        testRailPrint("Then \(card2) is a destination note in web mode when switching tabs")
        helper.shortcutActionInvoke(action: .jumpToNextTab)
        XCTAssertTrue(wait.waitForStringValueEqual(card2, webView.getDestinationCardElement(), minimumWaitTimeout))
    }
    
    func assertDestinationCard(_ cardName: String) {
        XCTAssertTrue(WaitHelper().waitForStringValueEqual(cardName, webView.getDestinationCardElement()), "Destination note is not \(cardName), but \(String(describing: webView.getDestinationCardElement().value))")
    }
}
