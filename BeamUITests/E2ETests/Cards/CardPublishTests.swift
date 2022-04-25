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
    var allCardsView: AllCardsTestView!
    let shortcuts = ShortcutsHelper()
    let dialogView = DialogTestView()
    
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
        step("Given I open all cards menu"){
            shortcuts.shortcutActionInvoke(action: .showAllCards)
            allCardsView = AllCardsTestView()
        }
        
        step("Then I see a label with instructions to publish note and redirected to Onboarding view on click") {
            allCardsView.getPublishInstructionsLabel().clickOnExistence()
            XCTAssertTrue(OnboardingLandingTestView().isOnboardingPageOpened())
            shortcuts.shortcutActionInvoke(action: .close)
        }
        
        step("When I open a default card") {
            cardView = allCardsView.openFirstCard()
        }
        
        step("Then by default there is no copy link button"){
            XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I try to publish the card") {
            cardView.publishCard()
        }

        step("Then I get the connect alert message and link button doesn't appear") {
            XCTAssertTrue(dialogView.app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(dialogView.app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].exists)
        }
        
        step("Then link button doesn't appear on Cancel button click") {
            dialogView.getButton(locator: .cancelButton).tapInTheMiddle()
            XCTAssertFalse(cardView.image(CardViewLocators.Buttons.copyCardLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then Onboarding view appears on Connect button click") {
            cardView.publishCard()
            dialogView.getButton(locator: .connectButton).tapInTheMiddle()
            XCTAssertTrue(OnboardingLandingTestView().isOnboardingPageOpened())
        }
    }
    
    
    
    func testPublishUnpublishNote() throws {
        try XCTSkipIf(true, "To be included after https://linear.app/beamapp/issue/BE-3934/uitestmenu-sign-in-with-correct-pk fix")
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
