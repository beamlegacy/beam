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
    
    // TODO: Once BE-1629 is fixed - retest
    func testAddTextToNewCard() throws {
        try XCTSkipIf(true, "Test is failed due to BE-1629")
        launchApp()
        UITestsMenuBar().destroyDB()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        
        print("Given I open Test page")
        helper.openTestPage(page: .page3)
    
        let textElementToAdd = pnsView.staticText(" capital letter \"I\". The purpose of this cursor is to indicate that the text beneath the cursor can be highlighted, and sometime")
        
        pnsView.addToCardByName(textElementToAdd, cardNameToBeCreated, "", true)
        
        print("Then it is successfully added to the card")
        XCTAssertTrue(pnsView.assertAddedToCardSuccessfully(cardNameToBeCreated))
        OmniBarTestView().navigateToCardViaPivotButton()
        let cardView = CardTestView()
        _ = cardView.waitForCardViewToLoad()
        let cardNotes = cardView.getCardNotesForVisiblePart()
        
        print("Then 2 non-empty notes are added")
        XCTAssertEqual(cardNotes.count, 2)
        XCTAssertNotEqual(cardNotes[0].value as? String, "", "note added is an empty string")
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
        XCTAssertEqual(cardNotes.count, 3)
        XCTAssertEqual(cardNotes[0].value as? String, "Point And Shoot Test Fixture Cursor")
        XCTAssertEqual(cardNotes[1].value as? String, "The pointer hotspot is the active pixel of the pointer, used to target a click or drag. The hotspot is normally along the pointer edges or in its center, though it may reside at any location in the pointer.[9][10][11]")
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
        XCTAssertEqual(cardNotes.count, 4) //4 as far as link is considered as a note by accessibility
        XCTAssertEqual(cardNotes[2].value as? String, noteText)
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
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-1751/pns-adding-to-a-card-fails-for-google-images")
        launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        helper.openTestPage(page: .media)
        
        let itemToCollect = pnsView.app.groups.containing(.button, identifier:"Play Video").children(matching: .group).element.children(matching: .group).element
        pnsView.addToTodayCard(itemToCollect)
    }
    
    func testFailedToCollect() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-1967/failed-to-collect-still-adds-a-link-to-a-card")
        let journalView = launchApp()
        let pnsView = PnSTestView()
        let helper = BeamUITestsHelper(pnsView.app)
        helper.openTestPage(page: .media)
        
        let itemToCollect = pnsView.app.windows.groups["Audio Controls"].children(matching: .group).element(boundBy: 1).children(matching: .slider).element
        pnsView.addToTodayCard(itemToCollect)

        print("Then Failed to collect message appears")
        pnsView.passFailedToCollectPopUpAlert()
        XCTAssertTrue(pnsView.staticText(PnSViewLocators.StaticTexts.failedCollectPopup.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        OmniBarTestView().navigateToCardViaPivotButton()
        journalView.waitForJournalViewToLoad()
        let cardNotes = CardTestView().getCardNotesForVisiblePart()
        XCTAssertEqual(cardNotes.count, 0)
    }
}
