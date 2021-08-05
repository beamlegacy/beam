//
//  CardEditTests.swift
//  BeamUITests
//
//  Created by Andrii on 27.07.2021.
//

import Foundation
import XCTest

class CardEditTests: BaseTest {
    
    func testRenameCardSuccessfully() throws {
        try XCTSkipIf(true, "Card title to be changed is not reachable so far")
        let cardNameToBeCreated = "RenameCard"
        let expectedCardRenameFirstTime = "Rename"
        let expectedCardRenameSecondTime = "Renamed2"
        let numberOfLetterToBeDeleted = 4
        
        let journalView = launchApp()
                                                
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("When I delete \(numberOfLetterToBeDeleted) letters from the title")
        cardView.cardTitle.click()
        cardView.typeKeyboardKey(.delete, numberOfLetterToBeDeleted)
        cardView.typeKeyboardKey(.enter)
        
        print("Then card title is changed to \(expectedCardRenameFirstTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime)
        
        print("When I type \(expectedCardRenameSecondTime) to the title")
        cardView.openEditorOptions()
        cardView.staticText(CardViewLocators.Buttons.contextMenuRename.accessibilityIdentifier).click()
        cardView.cardTitle.typeText(expectedCardRenameSecondTime)
        cardView.typeKeyboardKey(.enter)
        
        print("Then card's title is changed to \(expectedCardRenameFirstTime + expectedCardRenameSecondTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime + expectedCardRenameSecondTime)
    }
    
    func testRenameCardError() throws {
        try XCTSkipIf(true, "Card title to be changed is not reachable so far")
        let cardNameToBeCreated = "Rename"
        let cardTwoNameToBeCreated = "Renamed"
        let expectedErrorMessage = "This card’s title already exists in your knowledge base"
        
        let journalView = launchApp()
        
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("When I delete last letter from the title")
        journalView.searchInOmniBar(cardTwoNameToBeCreated, false)
        WebTestView().selectCreateCard(cardTwoNameToBeCreated)
        cardView.cardTitle.click()
        cardView.typeKeyboardKey(.delete)
        
        print("Then the following error appears \(expectedErrorMessage)")
        XCTAssertTrue(cardView.staticText(expectedErrorMessage).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testPublishCard() throws {
        try XCTSkipIf(true, "Publish logic is changed requiring signing in. Easy way to auth tbd")
        let cardNameToBeCreated = "Card publish"
        let journalView = launchApp()
        
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("Then the card is private by default")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.privateLock.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        print("When I publish the card")
        cardView.publishCard()
        
        print("Then published label and link icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.publishedLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.copyLinkButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        print("When I open editor")
        cardView.image(CardViewLocators.Buttons.editorButton.accessibilityIdentifier).click()
        
        print("Then copy link, invite, unpublish options are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.copyLinkLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.inviteLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testUnpublishPublishedCard() throws {
        try XCTSkipIf(true, "Card title to be changed is not reachable so far")
        let cardNameToBeCreated = "Unpublish"
        let journalView = launchApp()
        
        print("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        print("When I publish and then unpublish the card")
        cardView.publishCard()
        cardView.unpublishCard()
        
        print("Then private label and lock icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.privateLock.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
    
}
