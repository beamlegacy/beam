//
//  CardPublishTests.swift
//  BeamUITests
//
//  Created by Andrii on 05/10/2021.
//

import Foundation
import XCTest

class CardPublishTests: BaseTest {
    
    func testDefaultPublishStatus() {
        launchApp()
        testRailPrint("Given I publish default note without being logged in")
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        let cardView = AllCardsTestView().openFirstCard()
        
        testRailPrint("Then by default there is no copy link button")
        XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
        
        cardView.publishCard()
        testRailPrint("Then I get the error message and link button doesn't appear")
        XCTAssertTrue(cardView.staticText("You need to be logged in").waitForExistence(timeout: minimumWaitTimeout))
        XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout))
    }
    
    func SKIPtestPublishCard() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-2159/perform-uitest-locally-trigger-the-vinyl-fatalerror")
        let cardNameToBeCreated = "Note publish"
        let journalView = JournalTestView()
        launchAppWithArgument(uiTestModeLaunchArgument)
        //UITestsMenuBar().logout()
        UITestsMenuBar().signInApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) note")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
                                                                        
        testRailPrint("Then the note is private by default")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.publishLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
                        
        testRailPrint("When I publish the note")
        cardView.publishCard()
        
        testRailPrint("Then published label and link icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.publishedLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("Then I can open the link in web browser")
    }
    
    func SKIPtestPublishedCardContentCorrectness() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-2159/perform-uitest-locally-trigger-the-vinyl-fatalerror")
    }
    
    func SKIPtestUnpublishPublishedCard() throws {
        try XCTSkipIf(true, "Blocked by https://linear.app/beamapp/issue/BE-2159/perform-uitest-locally-trigger-the-vinyl-fatalerror")
        let cardNameToBeCreated = "Unpublish"
        let journalView = launchApp()
        
        testRailPrint("Given I create \(cardNameToBeCreated) note")
        //To be replaced with UITests helper - card creation
        let cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        
        testRailPrint("When I publish and then unpublish the note")
        cardView.publishCard()
        cardView.unpublishCard()
        
        testRailPrint("Then private label and lock icon are displayed")
        XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.privateLabel.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
        XCTAssertTrue(cardView.image(CardViewLocators.Buttons.privateLock.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout))
    }    
}
