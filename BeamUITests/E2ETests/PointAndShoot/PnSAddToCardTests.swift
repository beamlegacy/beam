//
//  PnSAddToCardTests.swift
//  BeamUITests
//
//  Created by Andrii on 17.09.2021.
//

import Foundation
import XCTest

class PnSAddToCardTests: BaseTest {
       
    let cardNameToBeCreated = "PnS Card"
    
    func testAddTextToTodaysCard() throws {
        try XCTSkipIf(true, "Skipped so far, to replace NavigationCollectUITests")
        let journalView = launchApp()
        UITestsMenuBar().destroyDB()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        let expectedItemText1 = "Point And Shoot Test Fixture Cursor"
        let expectedItemText2 = "Go to UITests-1"
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        print("When I point and shoot the following text and add it to Todays card")
        let prefix = "Go to "
        let linkText = "UITests-1"
        let parent = pnsView.app.webViews.containing(.staticText, identifier: linkText).element
        let textElement = parent.staticTexts[prefix].firstMatch
        pnsView.addToTodayCard(textElement)
        let todaysDateInCardTitleFormat = DateHelper().getTodaysDateString(.cardViewTitle)
        
        print("Then it is successfully added to the card")
        XCTAssertTrue(pnsView.assertAddedToCardSuccessfully(todaysDateInCardTitleFormat))
        OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()
        let cardNotes = CardTestView().getCardNotesForVisiblePart()
        
        print("Then \(expectedItemText1) and \(expectedItemText2) items are displayed in the card")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardNotes[0].value as? String, expectedItemText1)
        XCTAssertEqual(cardNotes[1].value as? String, expectedItemText2)
    }
    
    func testAddTextToNewCard() {
        launchApp()
        UITestsMenuBar().destroyDB()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
    
        let textElementToAdd = pnsView.staticText(" capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated, "", true)
        
        print("Then it is successfully added to the card")
        // Commented out as far as it is too unreliable
        //XCTAssertTrue(pnsView.assertAddedToCardSuccessfully(cardNameToBeCreated))
        OmniBarTestView().navigateToCardViaPivotButton()
        let cardView = CardTestView()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        
        print("Then 2 non-empty notes are added")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertNotEqual(cardView.getElementStringValue(element: cardNotes[0]), emptyString, "note added is an empty string")
    }
    
    func testAddTextToExistingCard() {
        let journalView = launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
    
        let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated)
        
        print("Then it is successfully added to the card")
        XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.addedToPopup.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        OmniBarTestView().navigateToCardViaPivotButton()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        
        print("Then 2 non-empty notes are added to an empty first one?")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), "Point And Shoot Test Fixture Cursor")
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[1]), "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
    }
    
    func testAddTextUsingNotes() {
        let noteText = "this is a note"
        let journalView = launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        testRailPrint("When I collect a text via PnS")
        let textElementToAdd = pnsView.staticText(". The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated, noteText)
        
        print("Then it is successfully added to the card")
        OmniBarTestView().navigateToCardViaPivotButton()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 3) //4 as far as link is considered as a note by accessibility
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[2]), noteText)
    }
    
    func testCollectImage() throws {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        let pnsView = PnSTestView()
        
        print("Given I create \(cardNameToBeCreated) card")
        journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("Then I successfully collect gif")
        helper.openTestPage(page: .page2)
        let webView = WebTestView()
        let gifItemToAdd = pnsView.image("File:Beam mode 2.gif")
        pnsView.addToCardByName(gifItemToAdd, cardNameToBeCreated)
        XCTAssertEqual(webView.openDestinationCard().getNumberOfImageNotes(), 1)
        
        testRailPrint("Then I successfully collect image")
        helper.openTestPage(page: .page4)
        let imageItemToAdd = pnsView.image("forest")
        pnsView.addToCardByName(imageItemToAdd, cardNameToBeCreated)
        XCTAssertEqual(webView.openDestinationCard().getNumberOfImageNotes(), 2)
    }
    
    func testCollectVideo() throws {
        let journalView = launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        helper.openTestPage(page: .media)
        
        let itemToCollect = pnsView.app.groups.containing(.button, identifier:"Play Video").children(matching: .group).element.children(matching: .group).element
        pnsView.addToTodayCard(itemToCollect)

        testRailPrint("Then switch to journal")
        let cardView = OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()

        testRailPrint("Then the note contains video link")
        let cardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), "Media Player Test Page")
        if let videoNote = cardNotes[1].value as? String {
            XCTAssertTrue(videoNote.contains("Beam.app/Contents/Resources/video.mov"))
        } else {
            XCTFail("expected cardNote[1].value to be a string")
        }
    }

    func testFailedToCollect() throws {
        // If this test is flakey, make sure browsing collect is disabled first
        let journalView = launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)

        testRailPrint("When the journal is first loaded the note is empty by default")
        let cardView = CardTestView()
        let beforeCardNotes = cardView.getCardNotesForVisiblePart()
        XCTAssertEqual(beforeCardNotes.count, 1)
        XCTAssertEqual(cardView.getElementStringValue(element: beforeCardNotes[0]), emptyString)
        helper.openTestPage(page: .media)
        let itemToCollect = pnsView.app.windows.groups["Audio Controls"].children(matching: .group).element(boundBy: 1).children(matching: .slider).element
        pnsView.addToTodayCard(itemToCollect)

        testRailPrint("Then Failed to collect message appears")
        pnsView.passFailedToCollectPopUpAlert()
        XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.failedCollectPopup.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()

        testRailPrint("Then the note is still empty")
        let cardNotes = CardTestView().getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 1)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), emptyString)
    }
    
    func testCollectFullPage() {
        launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        let shortcutsHelper = ShortcutsHelper()
        let expectedNoteText = "Point And Shoot Test Fixture Cursor"
        
        testRailPrint("Given I open Test page")
        helper.openTestPage(page: .page3)
        
        testRailPrint("When I collect full page")
        shortcutsHelper.shortcutActionInvoke(action: .collectFullPage)
        pnsView.waitForCollectPopUpAppear()
        pnsView.typeKeyboardKey(.enter)
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        
        testRailPrint("Then I see \(expectedNoteText) as collected link")
        let cardView = CardTestView()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        //To be refactored once BE-2117 merged
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[0]), expectedNoteText)
        XCTAssertEqual(cardView.getElementStringValue(element: cardNotes[1]), expectedNoteText)
        
        testRailPrint("When I try to collect full page for empty tab")
        shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        shortcutsHelper.shortcutActionInvoke(action: .newTab)
        shortcutsHelper.shortcutActionInvoke(action: .collectFullPage)
        
        testRailPrint("Then collect page doesn't appear")
        XCTAssertFalse(pnsView.waitForCollectPopUpAppear(), "Collect pop-up appeared for an empty page")
    }
}
