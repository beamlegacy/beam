//
//  NoteEditTests.swift
//  BeamUITests
//
//  Created by Andrii on 27.07.2021.
//

import Foundation
import XCTest

class NoteEditTests: BaseTest {
    
    var noteView: NoteTestView!
    
    func testRenameNoteSuccessfully() {
        let noteNameToBeCreated = "RenameNote"
        let expectedNoteRenameFirstTime = "Rename"
        let expectedNoteRenameSecondTime = "Renamed2"
        let numberOfLetterToBeDeleted = 4
        
        let journalView = launchApp()
        
                                                
        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            noteView = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        }
        
        step("When I delete \(numberOfLetterToBeDeleted) letters from the title"){
            noteView.makeNoteTitleEditable()
            noteView.typeKeyboardKey(.delete, numberOfLetterToBeDeleted)
            noteView.typeKeyboardKey(.enter)
        }
        
        
        step("Then note title is changed to \(expectedNoteRenameFirstTime)"){
            XCTAssertEqual(noteView.getNoteTitle(), expectedNoteRenameFirstTime)
        }
        
        step("When I type \(expectedNoteRenameSecondTime) to the title"){
            noteView.makeNoteTitleEditable().typeText(expectedNoteRenameSecondTime)
            noteView.typeKeyboardKey(.enter)
        }

        step("Then note's title is changed to \(expectedNoteRenameFirstTime + expectedNoteRenameSecondTime)"){
            XCTAssertEqual(noteView.getNoteTitle(), expectedNoteRenameFirstTime + expectedNoteRenameSecondTime)
        }
    }
    
    func testRenameNoteError() throws {
        let noteNameToBeCreated = "Rename"
        let noteTwoNameToBeCreated = "Renamed"
        let expectedErrorMessage = "This note’s title already exists in your knowledge base"
        
        let journalView = launchApp()
        
        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            noteView = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        }
        
        step("When I delete last letter from the title"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            journalView.searchInOmniBox(noteTwoNameToBeCreated, false)
            webView.selectCreateNote(noteTwoNameToBeCreated)
            noteView.makeNoteTitleEditable()
            noteView.typeKeyboardKey(.delete)
        }
        
        step("Then the following error appears \(expectedErrorMessage)"){
            XCTAssertTrue(noteView.staticText(expectedErrorMessage).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
    }
    
    func testNoteDeleteSuccessfully() {
        let noteNameToBeCreated = "Delete me"
        let journalView = launchApp()
        
        step("Given I create \(noteNameToBeCreated) note"){
            //To be replaced with UITests helper - note creation
            noteView = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        }
        
        step("When I try to delete \(noteNameToBeCreated) and cancel it"){
            noteView
                .clickDeleteButton()
                .cancelButtonClick()
        }
        
        step("Then the note is not deleted"){
            XCTAssertEqual(noteView.getNoteTitle(), noteNameToBeCreated, "\(noteNameToBeCreated) is deleted")
        }
        
        step("When I try to delete \(noteNameToBeCreated) and confirm it"){
            noteView
                .clickDeleteButton()
                .confirmDeletion()
        }
        
        step("Then the note is deleted"){
            XCTAssertFalse(journalView.openAllNotesMenu().isNoteNameAvailable(noteNameToBeCreated), "\(noteNameToBeCreated) note is not deleted")
        }
    }
    
    func testImageNotesSourceIconRedirectonToWebSource() {
        let pnsView = PnSTestView()
        
        step("When I add image to a note"){
            BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayNote(imageItemToAdd)
        }
        
        step("Then it has a source icon"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView = NoteTestView()
            noteView.waitForNoteViewToLoad()
            let imageNote = noteView.getImageNodeByIndex(nodeIndex: 0)
            imageNote.hover()
            XCTAssertTrue(noteView.button(NoteViewLocators.Buttons.sourceButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then I'm redirected to the source page when clicking on the icon"){
            noteView.button(NoteViewLocators.Buttons.sourceButton.accessibilityIdentifier).tapInTheMiddle()
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            let webPageUrl = webView.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(webPageUrl.hasSuffix("/UITests-4.html"), "Actual web page is \(webPageUrl)")
        }
       
    }

    func testMoveHandleAppearsHoverNode() {
        let pnsView = PnSTestView()

        step("When I add image to a note"){
            BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayNote(imageItemToAdd)
        }

        step("Then it has a move handle"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView = NoteTestView()
            noteView.waitForNoteViewToLoad()
            let imageNote = noteView.getImageNodeByIndex(nodeIndex: 0)
            imageNote.hover()
            XCTAssertTrue(noteView.handle(NoteViewLocators.Buttons.moveHandle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testMoveBulletsUsingShortcuts() {
        var nodesBeforeChange = [String]()
        step("GIVEN I populate today's note with the rows") {
            let journalView = launchApp()
            noteView = journalView.createNoteViaOmniboxSearch("Bullets")
            BeamUITestsHelper(journalView.app).tapCommand(.insertTextInCurrentNote)
            nodesBeforeChange = noteView.getNoteTextsForVisiblePart()
        }
        
        step("WHEN I drag the bullet down") {
            noteView?.typeKeyboardKey(.downArrow, 2)
            shortcutHelper.shortcutActionInvoke(action: .moveBulletDown)
        }
        
        step("THEN nodes are correctly placed") {
            let nodesAfterDraggingDown = noteView.getNoteTextsForVisiblePart()
            let expectedNotesAfterDraggingDown = [nodesBeforeChange[0], nodesBeforeChange[1], nodesBeforeChange[3], nodesBeforeChange[2], nodesBeforeChange[4]];
            XCTAssertTrue(nodesAfterDraggingDown == expectedNotesAfterDraggingDown)
        }
        
        step("WHEN I drag the bullet up") {
            noteView?.typeKeyboardKey(.downArrow)
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .moveBulletUp, numberOfTimes: 3)
        }
        
        step("THEN nodes are correctly placed") {
            let nodesAfterDraggingUp = noteView.getNoteTextsForVisiblePart()
            let expectedNotesAfterDraggingUp = [nodesBeforeChange[0], nodesBeforeChange[4], nodesBeforeChange[1], nodesBeforeChange[3], nodesBeforeChange[2]];
            XCTAssertTrue(nodesAfterDraggingUp == expectedNotesAfterDraggingUp)
        }
    }
    
    func testOptionCmdBackpaceShortucsUsage() {
        let noteNameToBeCreated = "DeleteShortcuts"
        let firstPart = "text "
        let secondPart = "to be "
        let thirdPart = "deleted"
        let journalView = launchApp()
        noteView = journalView.createNoteViaOmniboxSearch(noteNameToBeCreated)
        
        step("When I use Option+backspace and CMD+backspace on empty note"){
            shortcutHelper.shortcutActionInvoke(action: .removeLastWord)
            shortcutHelper.shortcutActionInvoke(action: .removeEntireLine)
        }
        
        step("Then nothing happens"){
            XCTAssertTrue(waitForStringValueEqual(emptyString, (noteView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I populate the row with the text \(firstPart + secondPart + thirdPart)") {
            noteView?.typeInNoteNodeByIndex(noteIndex: 0, text: firstPart + secondPart + thirdPart, needsActivation: true)
        }
        
        step("When I use Option+backspace once"){
            shortcutHelper.shortcutActionInvoke(action: .removeLastWord)
        }
        
        step("Then the following part of text is left:\(firstPart + secondPart)"){
            XCTAssertTrue(waitForStringValueEqual(firstPart + secondPart, (noteView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I use Option+backspace twice") {
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .removeLastWord, numberOfTimes: 2)
        }
        
        step("Then the following part of text is left:\(firstPart)"){
            XCTAssertTrue(waitForStringValueEqual(firstPart, (noteView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I add to the row the following text \(secondPart + thirdPart)") {
            noteView?.typeInNoteNodeByIndex(noteIndex: 0, text: secondPart + thirdPart, needsActivation: true)
        }
        
        step("When I use CMD+backspace twice") {
            shortcutHelper.shortcutActionInvoke(action: .removeEntireLine)
        }
        
        step("Then the row is empty"){
            XCTAssertTrue(waitForStringValueEqual(emptyString, (noteView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
    }
}
