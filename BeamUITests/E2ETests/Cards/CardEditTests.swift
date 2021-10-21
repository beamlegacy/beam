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
                                                
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("When I delete \(numberOfLetterToBeDeleted) letters from the title")
        cardView.cardTitle.click()
        cardView.typeKeyboardKey(.delete, numberOfLetterToBeDeleted)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card title is changed to \(expectedCardRenameFirstTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime)
        
        testRailPrint("When I type \(expectedCardRenameSecondTime) to the title")
        cardView.openEditorOptions()
        cardView.staticText(CardViewLocators.Buttons.contextMenuRename.accessibilityIdentifier).click()
        cardView.cardTitle.typeText(expectedCardRenameSecondTime)
        cardView.typeKeyboardKey(.enter)
        
        testRailPrint("Then card's title is changed to \(expectedCardRenameFirstTime + expectedCardRenameSecondTime)")
        XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime + expectedCardRenameSecondTime)
    }
    
    func testRenameCardError() throws {
        try XCTSkipIf(true, "Card title to be changed is not reachable so far")
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
        cardView.cardTitle.click()
        cardView.typeKeyboardKey(.delete)
        
        testRailPrint("Then the following error appears \(expectedErrorMessage)")
        XCTAssertTrue(cardView.staticText(expectedErrorMessage).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testPublishCard() throws {
        try XCTSkipIf(true, "Publish logic is changed requiring signing in. Easy way to auth tbd")
        let cardNameToBeCreated = "Card publish"
        let journalView = launchApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("Then the card is private by default")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.privateLock.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I publish the card")
        cardView.publishCard()
        
        testRailPrint("Then published label and link icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.publishedLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.copyLinkButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I open editor")
        cardView.image(CardViewLocators.Buttons.editorButton.accessibilityIdentifier).click()
        
        testRailPrint("Then copy link, invite, unpublish options are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.copyLinkLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.inviteLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.unpublishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
    
    func testUnpublishPublishedCard() throws {
        try XCTSkipIf(true, "Card title to be changed is not reachable so far")
        let cardNameToBeCreated = "Unpublish"
        let journalView = launchApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) card")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmnibarSearch(cardNameToBeCreated)
        
        testRailPrint("When I publish and then unpublish the card")
        cardView.publishCard()
        cardView.unpublishCard()
        
        testRailPrint("Then private label and lock icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.privateLock.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }
}
