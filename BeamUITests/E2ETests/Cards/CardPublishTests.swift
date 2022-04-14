//
//  CardPublishTests.swift
//  BeamUITests
//
//  Created by Andrii on 05/10/2021.
//

import Foundation
import XCTest

class CardPublishTests: BaseTest {
    
    var cardView: CardTestView!
    let shortcuts = ShortcutsHelper()
    
    private func switchReloadAndAssert(cardName: String, isPublished: Bool = true) {
        shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
        shortcuts.shortcutActionInvoke(action: .reloadPage)
        if isPublished {
            XCTAssertTrue(WebTestView().waitForPublishedNoteToLoad(noteName: cardName))
        } else {
            XCTAssertFalse(WebTestView().waitForPublishedNoteToLoad(noteName: cardName))
        }
    }
    
    func testDefaultPublishStatus() {
        launchApp()
        step("Given I publish default note without being logged in"){
            shortcuts.shortcutActionInvoke(action: .showAllCards)
            cardView = AllCardsTestView().openFirstCard()
        }
        
        step("Then by default there is no copy link button"){
            XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            cardView.publishCard()
        }

        step("Then I get the connect alert message and link button doesn't appear"){
            XCTAssertTrue(cardView.app.dialogs.staticTexts["Connect to Beam"].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(cardView.app.dialogs.buttons["Connect"].exists)
            cardView.app.dialogs.buttons["Cancel"].click()
            XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testPublishUnpublishNote() throws {
        
        let journalView = launchAppWithArgument(uiTestModeLaunchArgument)
        UITestsMenuBar().signInApp()
        let cardNameToBeCreated = "Note publish"
        let shortcuts = ShortcutsHelper()
        
        step("Given I create \(cardNameToBeCreated) note"){
            cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("When I publish the note") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            cardView.publishCard()
        }
        
        step("Then I can open it in the web") {
            XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            shortcuts.shortcutActionInvoke(action: .newTab)
            shortcuts.shortcutActionInvoke(action: .paste)
            cardView.typeKeyboardKey(.enter)
            XCTAssertTrue(WebTestView().waitForPublishedNoteToLoad(noteName: cardNameToBeCreated))
        }
        
        step("When I unpublish the note") {
            shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView.unpublishCard()
        }
        
        step("Then I can not open it in the web") {
            switchReloadAndAssert(cardName: cardNameToBeCreated, isPublished: false)
        }
        
        step("When I publish the note") {
            shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView.publishCard()
        }
        
        step("Then I can open it in the web") {
            switchReloadAndAssert(cardName: cardNameToBeCreated)
        }
        
        step("When I delete the note") {
            shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView
                .clickDeleteButton()
                .confirmDeletion()
        }
        
        step("Then I can not open it in the web") {
            switchReloadAndAssert(cardName: cardNameToBeCreated, isPublished: false)
        }
    }
    
    func SKIPtestPublishedCardContentCorrectness() throws {
        try XCTSkipIf(true, "TBD Make sure the content is correctly applied on changes")
    }
    
}
