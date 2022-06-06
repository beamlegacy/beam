//
//  CardEditTests.swift
//  BeamUITests
//
//  Created by Andrii on 27.07.2021.
//

import Foundation
import XCTest

class NoteEditTests: BaseTest {
    
    var cardView: CardTestView!
    let shortcutsHelper = ShortcutsHelper()
    
    func testRenameCardSuccessfully() {
        let cardNameToBeCreated = "RenameNote"
        let expectedCardRenameFirstTime = "Rename"
        let expectedCardRenameSecondTime = "Renamed2"
        let numberOfLetterToBeDeleted = 4
        
        let journalView = launchApp()
        
                                                
        step("Given I create \(cardNameToBeCreated) note"){
            //To be replaced with UITests helper - card creation
            cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("When I delete \(numberOfLetterToBeDeleted) letters from the title"){
            cardView.makeCardTitleEditable()
            cardView.typeKeyboardKey(.delete, numberOfLetterToBeDeleted)
            cardView.typeKeyboardKey(.enter)
        }
        
        
        step("Then note title is changed to \(expectedCardRenameFirstTime)"){
            XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime)
        }
        
        step("When I type \(expectedCardRenameSecondTime) to the title"){
            cardView.makeCardTitleEditable().typeText(expectedCardRenameSecondTime)
            cardView.typeKeyboardKey(.enter)
        }

        step("Then note's title is changed to \(expectedCardRenameFirstTime + expectedCardRenameSecondTime)"){
            XCTAssertEqual(cardView.getCardTitle(), expectedCardRenameFirstTime + expectedCardRenameSecondTime)
        }
    }
    
    func testRenameCardError() throws {
        let cardNameToBeCreated = "Rename"
        let cardTwoNameToBeCreated = "Renamed"
        let expectedErrorMessage = "This note’s title already exists in your knowledge base"
        
        let journalView = launchApp()
        
        step("Given I create \(cardNameToBeCreated) note"){
            //To be replaced with UITests helper - card creation
            cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("When I delete last letter from the title"){
            journalView.searchInOmniBox(cardTwoNameToBeCreated, false)
            WebTestView().selectCreateCard(cardTwoNameToBeCreated)
            cardView.makeCardTitleEditable()
            cardView.typeKeyboardKey(.delete)
        }
        
        step("Then the following error appears \(expectedErrorMessage)"){
            XCTAssertTrue(cardView.staticText(expectedErrorMessage).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
    }
    
    func testCardDeleteSuccessfully() {
        let cardNameToBeCreated = "Delete me"
        let journalView = launchApp()
        
        step("Given I create \(cardNameToBeCreated) note"){
            //To be replaced with UITests helper - card creation
            cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        }
        
        step("When I try to delete \(cardNameToBeCreated) and cancel it"){
            cardView
                .clickDeleteButton()
                .cancelDeletion()
        }
        
        step("Then the note is not deleted"){
            XCTAssertEqual(cardView.getCardTitle(), cardNameToBeCreated, "\(cardNameToBeCreated) is deleted")
        }
        
        step("When I try to delete \(cardNameToBeCreated) and confirm it"){
            cardView
                .clickDeleteButton()
                .confirmDeletion()
        }
        
        step("Then the note is deleted"){
            XCTAssertFalse(journalView.openAllCardsMenu().isCardNameAvailable(cardNameToBeCreated), "\(cardNameToBeCreated) card is not deleted")
        }
    }
    
    func testImageNotesSourceIconRedirectonToWebSource() {
        let pnsView = PnSTestView()
        let webView = WebTestView()
        
        step("When I add image to a note"){
            BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayCard(imageItemToAdd)
        }
        
        step("Then it has a source icon"){
            shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView = CardTestView()
            let imageNote = cardView.getImageNodeByIndex(nodeIndex: 0)
            imageNote.hover()
            XCTAssertTrue(cardView.button(CardViewLocators.Buttons.sourceButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("Then I'm redirected to the source page when clicking on the icon"){
            cardView.button(CardViewLocators.Buttons.sourceButton.accessibilityIdentifier).tapInTheMiddle()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            let webPageUrl = webView.getTabUrlAtIndex(index: 1)
            XCTAssertTrue(webPageUrl.hasSuffix("/UITests-4.html"), "Actual web page is \(webPageUrl)")
        }
       
    }

    func testMoveHandleAppearsHoverNode() {
        let pnsView = PnSTestView()

        step("When I add image to a note"){
            BeamUITestsHelper(launchApp().app).openTestPage(page: .page4)
            let imageItemToAdd = pnsView.image("forest")
            pnsView.addToTodayCard(imageItemToAdd)
        }

        step("Then it has a move handle"){
            shortcutsHelper.shortcutActionInvoke(action: .switchBetweenCardWeb)
            cardView = CardTestView()
            let imageNote = cardView.getImageNodeByIndex(nodeIndex: 0)
            imageNote.hover()
            XCTAssertTrue(cardView.handle(CardViewLocators.Buttons.moveHandle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    func testMoveBulletsUsingShortcuts() {
        var nodesBeforeChange = [String]()
        step("GIVEN I populate today's note with the rows") {
            let journalView = launchApp()
            cardView = journalView.createCardViaOmniboxSearch("Bullets")
            BeamUITestsHelper(journalView.app).tapCommand(.insertTextInCurrentNote)
            nodesBeforeChange = cardView.getCardNotesTextForVisiblePart()
        }
        
        step("WHEN I drag the bullet down") {
            cardView?.typeKeyboardKey(.downArrow, 2)
            shortcutsHelper.shortcutActionInvoke(action: .moveBulletDown)
        }
        
        step("THEN nodes are correctly placed") {
            let nodesAfterDraggingDown = cardView.getCardNotesTextForVisiblePart()
            let expectedNotesAfterDraggingDown = [nodesBeforeChange[0], nodesBeforeChange[1], nodesBeforeChange[3], nodesBeforeChange[2], nodesBeforeChange[4]];
            XCTAssertTrue(nodesAfterDraggingDown == expectedNotesAfterDraggingDown)
        }
        
        step("WHEN I drag the bullet up") {
            cardView?.typeKeyboardKey(.downArrow)
            shortcutsHelper.shortcutActionInvokeRepeatedly(action: .moveBulletUp, numberOfTimes: 3)
        }
        
        step("THEN nodes are correctly placed") {
            let nodesAfterDraggingUp = cardView.getCardNotesTextForVisiblePart()
            let expectedNotesAfterDraggingUp = [nodesBeforeChange[0], nodesBeforeChange[4], nodesBeforeChange[1], nodesBeforeChange[3], nodesBeforeChange[2]];
            XCTAssertTrue(nodesAfterDraggingUp == expectedNotesAfterDraggingUp)
        }
    }
    
    func testOptionCmdBackpaceShortucsUsage() {
        let cardNameToBeCreated = "DeleteShortcuts"
        let firstPart = "text "
        let secondPart = "to be "
        let thirdPart = "deleted"
        let journalView = launchApp()
        cardView = journalView.createCardViaOmniboxSearch(cardNameToBeCreated)
        
        step("When I use Option+backspace and CMD+backspace on empty note"){
            shortcutsHelper.shortcutActionInvoke(action: .removeLastWord)
            shortcutsHelper.shortcutActionInvoke(action: .removeEntireLine)
        }
        
        step("Then nothing happens"){
            XCTAssertTrue(waitForStringValueEqual(emptyString, (cardView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I populate the row with the text \(firstPart + secondPart + thirdPart)") {
            cardView?.typeInCardNoteByIndex(noteIndex: 0, text: firstPart + secondPart + thirdPart, needsActivation: true)
        }
        
        step("When I use Option+backspace once"){
            shortcutsHelper.shortcutActionInvoke(action: .removeLastWord)
        }
        
        step("Then the following part of text is left:\(firstPart + secondPart)"){
            XCTAssertTrue(waitForStringValueEqual(firstPart + secondPart, (cardView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I use Option+backspace twice") {
            shortcutsHelper.shortcutActionInvokeRepeatedly(action: .removeLastWord, numberOfTimes: 2)
        }
        
        step("Then the following part of text is left:\(firstPart)"){
            XCTAssertTrue(waitForStringValueEqual(firstPart, (cardView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
        
        step("When I add to the row the following text \(secondPart + thirdPart)") {
            cardView?.typeInCardNoteByIndex(noteIndex: 0, text: secondPart + thirdPart, needsActivation: true)
        }
        
        step("When I use CMD+backspace twice") {
            shortcutsHelper.shortcutActionInvoke(action: .removeEntireLine)
        }
        
        step("Then the row is empty"){
            XCTAssertTrue(waitForStringValueEqual(emptyString, (cardView?.getTextNodeByIndex(nodeIndex: 0))!))
        }
    }
}
