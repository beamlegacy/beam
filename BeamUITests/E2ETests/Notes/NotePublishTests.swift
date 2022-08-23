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
        testrailId("C1040")
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
        OmniBoxTestView().navigateToNoteViaPivotButton()
        let noteNameToBeCreated = "Test1"
        
        step("Given I create \(noteNameToBeCreated) note"){
            noteView = uiMenu.createAndOpenNote()
            XCTAssertTrue(noteView.waitForNoteViewToLoad(), "Note view wasn't loaded")
        }
        
        testrailId("C752")
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
        
        testrailId("C753")
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
        
        testrailId("C754")
        step("THEN profile link appears exist on Add to profile toggle click") {
            noteView.getAddToProfileToggleElement().tapInTheMiddle()
            XCTAssertTrue(noteView.getStagingProfileLinkElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("THEN profile web page is opened on profile link click") {
            noteView.getStagingProfileLinkElement().tapInTheMiddle()
            webView.waitForWebViewToLoad()
            webView.activateSearchFieldFromTab(index: 1)
            let tabURL = webView.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(tabURL.starts(with: self.stagingEnvironmentServerAddress), "\(tabURL) doesn't start with staging environment server address: \(self.stagingEnvironmentServerAddress)")
            XCTAssertTrue(webView.staticText(publishedNoteName).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        testrailId("C755")
        step("WHEN I open the note and disable the toggle") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
            noteView
                .clickPublishedMenuDisclosureTriangle().getAddToProfileToggleElement().tapInTheMiddle()
        }
        
        step("THEN the profile link disappears") {
            XCTAssertTrue(waitForDoesntExist(noteView.getStagingProfileLinkElement()), "\(self.stagingEnvironmentServerAddress) link is still visible")
        }
        
        testrailId("C564")
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
    
    func testCopyURLPublishedNote() {
        testrailId("C1160")
        let noteNameToBeCreated = "Test1"

        step("GIVEN I created and publish a note") {
            setupStaging(withRandomAccount: true)
            uiMenu.createAndOpenPublishedNote()
            noteView = NoteTestView()
        }
        
        step("When I click on Publish link") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            noteView.publishNote()
        }
        
        step("Then Link is copied I can open it in the web") {
            XCTAssertTrue(noteView.staticText(NoteViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
        }
        
        step("And I can open it in the web") {
            noteView.shortcutHelper.shortcutActionInvoke(action: .newTab)
            noteView.shortcutHelper.shortcutActionInvoke(action: .paste)
            noteView.typeKeyboardKey(.enter)
            XCTAssertTrue(webView.waitForPublishedNoteToLoad(noteName: noteNameToBeCreated))
        }

        
        step("When I copy URL through publish menu") {
            NSPasteboard.general.clearContents() //to clean the paste contents
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
            noteView.clickPublishedMenuDisclosureTriangle()
                .sharePublishedNoteMenuDisplay()
                .sharePublishedNoteAction(.shareCopyUrl)
        }
        
        step("Then I can open it in the web") {
            noteView.waitForNoteViewToLoad()
            noteView.shortcutHelper.shortcutActionInvoke(action: .newTab)
            noteView.shortcutHelper.shortcutActionInvoke(action: .paste)
            noteView.typeKeyboardKey(.enter)
            XCTAssertTrue(webView.waitForPublishedNoteToLoad(noteName: noteNameToBeCreated))
        }
    }
    
    private func verifySharePublishedNoteMenu() {
        for item in NoteViewLocators.SharePublishedNote.allCases {
            XCTAssertTrue(app.staticTexts[item.accessibilityIdentifier].exists)
        }
    }
    
    struct ShareMenu {
        let name: String
        let accId: NoteViewLocators.SharePublishedNote
    }
    
    func testSharePublishedNote() {
        testrailId("C1161")
        var shareOptions = [ShareMenu]()
        let twitterOption = ShareMenu(name: "Twitter", accId: .shareTwitter)
        let facebookOption = ShareMenu(name: "Facebook", accId: .shareFacebook)
//        let linkedinOption = ShareMenu(name: "LinkedIn", accId: .shareLinkedin) // to reactivate as part of BE-5195
        let redditOption = ShareMenu(name: "Reddit", accId: .shareReddit)
        
        shareOptions.append(contentsOf:[twitterOption, facebookOption, redditOption]) // add linkedinOption once BE-5195 is solved
        
        let apps = ["Mail", "Messages"]
        
        step("Given I created and publish a note") {
            setupStaging(withRandomAccount: true)
            uiMenu.createAndOpenPublishedNote()
            noteView = NoteTestView()
        }
        
        step("When I open share menu") {
            noteView.clickPublishedMenuDisclosureTriangle()
                .sharePublishedNoteMenuDisplay()
        }
        
        step ("Then \(apps.joined(separator: ",")) options exist in Share options") {
            XCTAssertTrue(app.staticTexts[NoteViewLocators.SharePublishedNote.shareLinkedin.accessibilityIdentifier].exists) //To be removed as part of BE-5195
            verifySharePublishedNoteMenu()
            noteView.typeKeyboardKey(.escape)
        }
        
        for i in 0 ... shareOptions.count - 1 {
            step ("Then \(shareOptions[i].name) window is opened using Share option") {
            noteView.clickPublishedMenuDisclosureTriangle()
                .sharePublishedNoteMenuDisplay()
                .sharePublishedNoteAction(shareOptions[i].accId)
            _ = webView.waitForWebViewToLoad()
            XCTAssertTrue(waitForIntValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getNumberOfWindows()), "Second window wasn't opened during \(BaseTest.implicitWaitTimeout) seconds timeout")
            XCTAssertTrue(
                noteView.isWindowOpenedWithContaining(title: shareOptions[i].name) ||
                noteView.isWindowOpenedWithContaining(title: shareOptions[i].name, isLowercased: true)
                )
            shortcutHelper.shortcutActionInvoke(action: .close)
            }
        }
    }
    
    func SKIPtestPublishedNoteContentCorrectness() throws {
        try XCTSkipIf(true, "TBD Make sure the content is correctly applied on changes")
    }
    
}
