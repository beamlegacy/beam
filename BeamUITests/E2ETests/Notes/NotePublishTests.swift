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
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        let noteNameToBeCreated = "Test1"
        
        step("Given I create \(noteNameToBeCreated) note"){
            uiMenu.createAndOpenNote()
        }
        
        step("When I publish the note") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            noteView.publishNote()
        }
        
        step("Then I can open it in the web") {
            XCTAssertTrue(noteView.staticText(NoteViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
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
    
    func testProfileAddAndRemovePublishedNote() {
        
        let notPublishedNotesLabel = "No Published Notes - beam"
        let publishedNoteName = "Test1"
        
        step("GIVEN I created and publish a note") {
            setupStaging(withRandomAccount: true)
            uiMenu.createAndOpenPublishedNote()
            noteView = NoteTestView()
            noteView.waitForNoteViewToLoad()
            noteView.clickPublishedMenuDisclosureTriangle()
        }
        
        step("THEN profile link doesn't exist") {
            XCTAssertFalse(noteView.getStagingProfileLinkElement().exists)
        }
        
        step("THEN profile link appears exist on Add to profile toggle click") {
            noteView.getAddToProfileToggleElement().tapInTheMiddle()
            XCTAssertTrue(noteView.getStagingProfileLinkElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("THEN profile web page is opened on profile link click") {
            noteView.getStagingProfileLinkElement().tapInTheMiddle()
            webView.waitForWebViewToLoad()
            webView.activateSearchFieldFromTab(index: 1)
            let tabURL = webView.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(tabURL.starts(with: BaseTest().stagingEnvironmentServerAddress), "\(tabURL) doesn't start with staging environment server address: \(BaseTest().stagingEnvironmentServerAddress)")
            XCTAssertTrue(webView.staticText(publishedNoteName).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("WHEN I open the note and disable the toggle") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
            noteView
                .clickPublishedMenuDisclosureTriangle().getAddToProfileToggleElement().tapInTheMiddle()
        }
        
        step("THEN the profile link disappears") {
            XCTAssertTrue(waitForDoesntExist(noteView.getStagingProfileLinkElement()), "\(BaseTest().stagingEnvironmentServerAddress) link is still visible")
        }
        
        step("WHEN I reload profile web page") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
            webView.waitForWebViewToLoad()
        }
        
        step("THEN I see \(notPublishedNotesLabel) label and \(publishedNoteName) note link doesn't exist") {
            XCTAssertTrue(webView.app.windows[notPublishedNotesLabel].waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(webView.staticText(publishedNoteName).exists)
        }
    }
    
    func SKIPtestPublishedNoteContentCorrectness() throws {
        try XCTSkipIf(true, "TBD Make sure the content is correctly applied on changes")
    }
    
}
