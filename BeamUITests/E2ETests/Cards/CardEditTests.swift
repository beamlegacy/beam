//
//  CardEditTests.swift
//  BeamUITests
//
//  Created by Andrii on 27.07.2021.
//

import Foundation
import XCTest

class CardEditTests: BaseTest {
    
    func testRenameCardSuccessfully() {
        let cardNameToBeCreated = "RenameCard"
        let expectedCardRenameFirstTime = "Rename"
        let expectedCardRenameSecondTime = "Renamed2"
        let numberOfLetterToBeDeleted = 4
        
        let journalView = launchApp()
                                                
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("When I delete \(numberOfLetterToBeDeleted) letters from the title")
        cardView.makeCardTitleEditable()
        cardView.typeKeyboardKey(.delete, numberOfLetterToBeDeleted)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card title is changed to \(expectedCardRenameFirstTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime)
        
        testRailPrint("When I type \(expectedCardRenameSecondTime) to the title")
        cardView.makeCardTitleEditable().typeText(expectedCardRenameSecondTime)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card's title is changed to \(expectedCardRenameFirstTime + expectedCardRenameSecondTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime + expectedCardRenameSecondTime)
    }
    
    func testRenameCardError() throws {
        let cardNameToBeCreated = "Rename"
        let cardTwoNameToBeCreated = "Renamed"
        let expectedErrorMessage = "This card’s title already exists in your knowledge base"
        
        let journalView = launchApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("When I delete last letter from the title")
        journalView.searchInOmniBar(cardTwoNameToBeCreated, false)
        WebTestView().selectCreateCard(cardTwoNameToBeCreated)
        cardView.makeCardTitleEditable()
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("Then the following error appears \(expectedErrorMessage)")
        XCTAssertTrue(cardView.staticText(expectedErrorMessage).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testCardDeleteSuccessfully() {
        let cardNameToBeCreated = "Delete"
        let journalView = launchApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        testRailPrint("When I try to delete \(cardNameToBeCreated) and cancel it")
        cardView
            .clickDeleteButton()
            .cancelDeletion()
        
        testRailPrint("Then the card is not deleted")
        XCTAssertEqual(cardView.getCardTitle(), cardNameToBeCreated, "\(cardNameToBeCreated) is deleted")
        
        testRailPrint("When I try to delete \(cardNameToBeCreated) and confirm it")
        cardView
            .clickDeleteButton()
            .confirmDeletion()
        
        testRailPrint("Then the card is deleted")
        XCTAssertFalse(journalView.openAllCardsMenu().isCardNameAvailable(cardNameToBeCreated), "\(cardNameToBeCreated) card is not deleted")
    }
    
    func testImageNotesSourceIconRedirectonToWebSource() {
        let pnsView = PnSTestView()
        let webView = WebTestView()
        
        testRailPrint("When I add image to a card")
        BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
        let imageItemToAdd = pnsView.image("forest")
        pnsView.addToTodayCard(imageItemToAdd)
        
        testRailPrint("Then it has a source icon")
        let cardView = webView.openDestinationCard()
        let imageNote = cardView.getImageNoteByIndex(noteIndex: 0)
        imageNote.hover()
        XCTAssertTrue(cardView.button(CardViewLocators.Buttons.sourceButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("Then I'm redirected to the source page when clicking on the icon")
        cardView.button(CardViewLocators.Buttons.sourceButton.accessibilityIdentifier).tapInTheMiddle()
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        let webPageUrl = OmniBarTestView().getSearchFieldValue()
        XCTAssertTrue(webPageUrl.hasSuffix("/UITests-4.html"), "Actual web page is \(webPageUrl)")
    }
    
    func testIntendUnintendNote() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-2234/perform-uitest-locally-trigger-the-vinyl-fatalerror")
        launchApp()
        
        let cardView = openFirstCardInAllCardsList()
        BeamUITestsHelper(cardView.app).tapCommand(.insertTextInCurrentNote)
        XCTAssertEqual(cardView.getCountOfDisclosureTriangles(), 0)
        cardView.clickDisclosureTriangleByIndex(0)
    }
}
