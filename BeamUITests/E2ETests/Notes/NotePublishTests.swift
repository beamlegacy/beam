//
//  NotePublishTests.swift
//  BeamUITests
//
//  Created by Andrii on 05/10/2021.
//

import Foundation
import XCTest

class NotePublishTests: BaseTest {
    
    var noteView: NoteTestView!
    var allNotesView: AllNotesTestView!
    var journalView: JournalTestView!
    let dialogView = DialogTestView()
    
    private func switchReloadAndAssert(noteName: String, isPublished: Bool = true) {
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        if isPublished {
            XCTAssertTrue(webView.waitForPublishedNoteToLoad(noteName: noteName))
        } else {
            XCTAssertFalse(webView.waitForPublishedNoteToLoad(noteName: noteName))
        }
    }
    
    func testDefaultPublishStatus() {
        launchApp()
        step("Given I open all notes menu"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
        }
        
        step("Then I see a label with instructions to publish note and redirected to Onboarding view on click") {
            allNotesView.getPublishInstructionsLabel().clickOnExistence()
            XCTAssertTrue(OnboardingLandingTestView().isOnboardingPageOpened())
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("When I open a default note") {
            noteView = allNotesView.openFirstNote()
        }
        
        step("Then by default there is no copy link button"){
            XCTAssertFalse(noteView.image(NoteViewLocators.Buttons.copyNoteLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I try to publish the note") {
            noteView.publishNote()
        }

        step("Then I get the connect alert message and link button doesn't appear") {
            XCTAssertTrue(dialogView.app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(dialogView.app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].exists)
        }
        
        step("Then link button doesn't appear on Cancel button click") {
            dialogView.getButton(locator: .cancelButton).tapInTheMiddle()
            XCTAssertFalse(noteView.image(NoteViewLocators.Buttons.copyNoteLinkButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then Onboarding view appears on Connect button click") {
            noteView.publishNote()
            dialogView.getButton(locator: .connectButton).tapInTheMiddle()
            XCTAssertTrue(OnboardingLandingTestView().isOnboardingPageOpened())
        }
    }
    
    func testPublishUnpublishNote() throws {

        journalView = setupStaging(withRandomAccount: true)
        
        XCTAssertTrue(webView.waitForWebViewToLoad(), "Webview is not loaded")
        journalView.shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        let noteNameToBeCreated = "Note publish"
        
        step("Given I create \(noteNameToBeCreated) note"){
            noteView = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        }
        
        step("When I publish the note") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            noteView.publishNote()
        }
        
        step("Then I can open it in the web") {
            XCTAssertTrue(noteView.staticText(NoteViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            noteView.shortcutHelper.shortcutActionInvoke(action: .newTab)
            noteView.shortcutHelper.shortcutActionInvoke(action: .paste)
            noteView.typeKeyboardKey(.enter)
            XCTAssertTrue(webView.waitForPublishedNoteToLoad(noteName: noteNameToBeCreated))
        }
        
        step("When I unpublish the note") {
            noteView.shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.unpublishNote()
        }
        
        step("Then I can not open it in the web") {
            switchReloadAndAssert(noteName: noteNameToBeCreated, isPublished: false)
        }
        
        step("When I publish the note") {
            journalView.shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.publishNote()
        }
        
        step("Then I can open it in the web") {
            switchReloadAndAssert(noteName: noteNameToBeCreated)
        }
        
        step("When I delete the note") {
            journalView.shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView
                .clickDeleteButton()
                .confirmDeletion()
        }
        
        step("Then I can not open it in the web") {
            switchReloadAndAssert(noteName: noteNameToBeCreated, isPublished: false)
        }
    }
    
    func SKIPtestPublishedNoteContentCorrectness() throws {
        try XCTSkipIf(true, "TBD Make sure the content is correctly applied on changes")
    }
    
}
