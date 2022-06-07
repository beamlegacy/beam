//
//  CardPublishTests.swift
//  BeamUITests
//
//  Created by Andrii on 05/10/2021.
//

import Foundation
import XCTest

class NotePublishTests: BaseTest {
    
    var cardView: NoteTestView!
    var allCardsView: AllNotesTestView!
    let shortcuts = ShortcutsHelper()
    let dialogView = DialogTestView()
    var deletePK = false
    var deleteRemoteAccount = false
    
    override func tearDown() {
        super.tearDown()
        if deletePK {
            UITestsMenuBar().deletePrivateKeys()
        }
        if deleteRemoteAccount {
            UITestsMenuBar().deleteRemoteAccount().resetAPIEndpoints()
        }
    }
    
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
            shortcuts.shortcutActionInvoke(action: .showAllNotes)
            allCardsView = AllNotesTestView()
        }
        
        step("Then I see a label with instructions to publish note and redirected to Onboarding view on click") {
            allCardsView.getPublishInstructionsLabel().clickOnExistence()
            XCTAssertTrue(OnboardingLandingTestView().isOnboardingPageOpened())
            shortcuts.shortcutActionInvoke(action: .close)
        }
        
        step("When I open a default card") {
            cardView = allCardsView.openFirstNote()
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
        deleteRemoteAccount = true
        deletePK = true
        let journalView = launchAppWithArgument(uiTestModeLaunchArgument)
        UITestsMenuBar()
            .setAPIEndpointsToStaging()
            .signUpWithRandomTestAccount()
        
        XCTAssertTrue(WebTestView().waitForWebViewToLoad(), "Webview is not loaded")
        journalView.shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
        let cardNameToBeCreated = "Note publish"
        
        step("Given I create \(cardNameToBeCreated) note"){
            cardView = journalView.createNoteViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("When I publish the note") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            cardView.publishCard()
        }
        
        step("Then I can open it in the web") {
            XCTAssertTrue(cardView.staticText(CardViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            cardView.shortcutsHelper.shortcutActionInvoke(action: .newTab)
            cardView.shortcutsHelper.shortcutActionInvoke(action: .paste)
            cardView.typeKeyboardKey(.enter)
            XCTAssertTrue(WebTestView().waitForPublishedNoteToLoad(noteName: cardNameToBeCreated))
        }
        
        step("When I unpublish the note") {
            cardView.shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView.unpublishCard()
        }
        
        step("Then I can not open it in the web") {
            switchReloadAndAssert(cardName: cardNameToBeCreated, isPublished: false)
        }
        
        step("When I publish the note") {
            journalView.shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView.publishCard()
        }
        
        step("Then I can open it in the web") {
            switchReloadAndAssert(cardName: cardNameToBeCreated)
        }
        
        step("When I delete the note") {
            journalView.shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
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
