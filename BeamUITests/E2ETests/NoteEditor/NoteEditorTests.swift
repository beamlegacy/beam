//
//  NoteEditorTests.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class NoteEditorTests: BaseTest {
    
    let cardTestView = NoteTestView()
    let shortcuts = ShortcutsHelper()
    let texts = [
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
    
        //Blocked by BE-2500 and BE-2502
                //"0º‚B†¹1¡ŽCçÇ2™€DÎ3£ÐE´4¢ðFƒÏ5ƒÞG©›6§þH™Ó7¶ýIˆ8•°JÔ9ª·Kš • – – endash— em dashL¬Ò=‚±MµÂ[“”OøØ]‘’P¼½´ªQœŒ‘æÆR®‰,¾SßÍ.„˜TÝ;…ÚU¨``V×/÷¿W…„X‰œY¥ÁZ‡", //åÅ for BE-2500 it was in the beginning
                //სხივი causes additional char to appear
        "Donec fringilla libero a dui tempus ornare. Nunc vestibulum at metus sit amet pellentesque. Aenean vitae nunc est. Ut et elit eu justo porttitor commodo. Curabitur egestas sem in pellentesque porta. Fusce dapibus mi nisi, non scelerisque felis rutrum vitae. Proin et libero mollis, sagittis lacus non, laoreet leo. Sed sodales scelerisque massa, quis tincidunt enim porttitor a. Donec ultricies purus ac commodo dictum. In rhoncus, massa egestas porttitor sollicitudin, purus mi luctus nisl, nec vehicula felis ante sit amet tellus. Maecenas bibendum quam tortor, consectetur suscipit lacus faucibus sed. Proin vitae imperdiet tortor, quis faucibus lectus.",
        //The part of the string to be kept an eye on in future
        //"Промінь Δέσμη", //빔 ビーム 光束", //Bjælke Stråle", //0º‚B†¹1¡ŽCçÇ2™€DÎ3£ÐE´4¢ðFƒÏ5ƒÞG©›6§þH™Ó7¶ýIˆ8•°JÔ9ª·Kš • – – endash— em dashL¬Ò=‚±MµÂ[“”OøØ]‘’P¼½´ªQœŒ‘æÆR®‰,¾SßÍ.„˜TÝ;…ÚU¨``V×/÷¿W…„X‰œY¥ÁZ‡",
    
        "The standard@chunk.com of Lorem Ipsum https://used.since.the 1500s is reproduced.com below for those interested. Sections 1.10.32 and 1.10.33 from de Finibus Bonorum et Malorum by Cicero are also reproduced in their exact original form, accompanied by English versions from the 1914 translation by H. Rackham."
    ]
    
    private func cmdClickFirstNote() {
        XCUIElement.perform(withKeyModifiers: .command) {
            cardTestView.getTextNodes()[0].coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.5)).tap()
        }
    }
    
    func testTypeTextInNote() {
        let journalView = launchApp()
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        let firstJournalEntry = journalView.getNoteByIndex(1)
        firstJournalEntry.clear()
        
        step("Then note displays typed text correctly"){
            cardTestView.getCardNotesForVisiblePart().first?.click()
            journalView.app.typeText(texts[0])
            XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[0])
        }

        step("Then note displays typed text from the beginning of the note correctly"){
            shortcuts.shortcutActionInvoke(action: .beginOfNote)
            journalView.app.typeText(texts[1])
            XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[1] + texts[0])
        }

        
        step("Then note displays replaced typed text correctly"){
            shortcuts.shortcutActionInvoke(action: .selectAll)
            journalView.app.typeText(texts[2])
            XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[2])
        }

        step("Then second note displays changed text correctly"){
            journalView.typeKeyboardKey(.enter)
            let expectedResult = BeamUITestsHelper(journalView.app).typeAndEditHardcodedText(journalView)
            XCTAssertEqual(journalView.getElementStringValue(element:journalView.getNoteByIndex(2)), expectedResult)
        }

    }
    
    func testSlashCommandsView() {
        let journalView = launchApp()
        let contextMenuTriggerKey = "/"
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        
        step("Given I type \(contextMenuTriggerKey) char"){
            cardTestView.getCardNotesForVisiblePart().first?.click()
            let firstJournalEntry = journalView.getNoteByIndex(1)
            firstJournalEntry.tapInTheMiddle()
            firstJournalEntry.clear()
        }
        let contextMenuView = cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)
        
        step("Then Context menu is displayed"){
            XCTAssertTrue(contextMenuView.menuElement().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step("Then Context menu items exist, enabled and hittable"){
            for item in NoteViewLocators.SlashContextMenuItems.allCases {
                let identifier = item.accessibilityIdentifier
                let element = contextMenuView.staticText(identifier).firstMatch
                XCTAssertTrue(element.exists && element.isEnabled && element.isHittable, "element \(identifier) couldn't be reached")
            }
        }

        step("When I press delete button"){
            journalView.typeKeyboardKey(.delete)
        }
        
        step("Then Context menu is NOT displayed"){
            XCTAssertTrue(waitForDoesntExist(contextMenuView.menuElement()))
        }
        
        journalView.app.typeText(contextMenuTriggerKey + "bol")
        let boldMenuItem = contextMenuView.staticText(NoteViewLocators.SlashContextMenuItems.boldItem.accessibilityIdentifier)
        
        step("Then Bold context menu item is displayed"){
            XCTAssertTrue(boldMenuItem.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }
        
        step("When I press return button"){
            journalView.typeKeyboardKey(.enter)
        }
        
        step("Then Bold context menu item is NOT displayed"){
            XCTAssertTrue(waitForDoesntExist(boldMenuItem))
        }
    }
    
    func testOpenTabOnBackground() {
        
        step("Given I open a note") {
            launchApp()
            shortcuts.shortcutActionInvoke(action: .showAllNotes)
            AllNotesTestView().waitForAllNotesViewToLoad()
            AllNotesTestView().openFirstNote()
        }
        
        step("Given I type a URL in text editor"){
            cardTestView.typeInCardNoteByIndex(noteIndex: 0, text: "youtube.com ", needsActivation: true)
        }
        
        step("When I CMD+click on URL"){
            self.cmdClickFirstNote()
        }
        
        step("Then I see pivot button value is incremented") {
            XCTAssertTrue(cardTestView.staticText(CardViewLocators.StaticTexts.backgroundTabOpened.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertEqual(cardTestView.getPivotButtonCounter(), "1")
            
            self.cmdClickFirstNote()
            XCTAssertEqual(cardTestView.getPivotButtonCounter(), "2")
        }
        
        step("Then correct number of tabs is opened"){
            shortcuts.shortcutActionInvoke(action: .switchBetweenCardWeb)
            XCTAssertEqual(WebTestView().getNumberOfTabs(), 2)
        }
    }
    
    func testTextNodeIndentationLevels() {
        launchAppAndOpenFirstNote()
        
        step("Given I create indentation levels") {
            cardTestView.typeInCardNoteByIndex(noteIndex: 0, text: "row1",  needsActivation: true)
            cardTestView.typeKeyboardKey(.return)
            cardTestView.typeKeyboardKey(.tab)
            
            cardTestView.app.typeText("row2")
            cardTestView.typeKeyboardKey(.return)
            
            cardTestView.app.typeText("row3")
            cardTestView.typeKeyboardKey(.return)
            cardTestView.typeKeyboardKey(.tab)
            
            cardTestView.app.typeText("row4")
            cardTestView.typeKeyboardKey(.return)
            
            cardTestView.app.typeText("row5")
            cardTestView.typeKeyboardKey(.tab)
            cardTestView.typeKeyboardKey(.return)
            
            cardTestView.app.typeText("row6")
        }
        
        step("Then there are 3 indentation disclosure triangles appeared for row 1, 3 and 4") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 3)
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 0))
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 2))
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 3))
        }
        
        step("When I unindent row5 2 times") {
            cardTestView.typeKeyboardKey(.upArrow)
            shortcuts.shortcutActionInvokeRepeatedly(action: .unindent, numberOfTimes: 2)
        }
        
        step("Then row5 and row6 positions are swapped") {
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(4), "row6")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(5), "row5")
        }
        
        step("When I close row3") {
            cardTestView.getIndentationTriangleAtNode(nodeIndex: 2).tapInTheMiddle()
        }
        
        step("Then the number of disclosure tirangles is 2 available for row 1 and 3, rows 4 and 5 are hidden") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 2)
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 0))
            XCTAssertTrue(cardTestView.isIndentationTriangleClosed(nodeIndex: 2))
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), "row1")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(1), "row2")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(2), "row3")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(3), "row5")
        }
        
        step("When I indent row5") {
            cardTestView.typeKeyboardKey(.tab)
        }
        
        step("Then number of disclosure tirangles is 3") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 3)
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 0))
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 2))
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 3))
        }
        
        step("When I unindent row5 and close row1") {
            shortcuts.shortcutActionInvokeRepeatedly(action: .unindent, numberOfTimes: 2)
            cardTestView.getIndentationTriangleAtNode(nodeIndex: 0).tapInTheMiddle()
        }
        
        step("Then number of disclosure tirangles is 1 available for row 1") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 1)
            XCTAssertTrue(cardTestView.isIndentationTriangleClosed(nodeIndex: 0))
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(1), "row5")
        }
        
        step("When I open row1 and close row4") {
            cardTestView.getIndentationTriangleAtNode(nodeIndex: 0).tapInTheMiddle()
            cardTestView.getIndentationTriangleAtNode(nodeIndex: 3).tapInTheMiddle()
        }
        
        step("Then number of disclosure tirangles is 2 available for row 3") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 3)
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 0))
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 2))
            XCTAssertTrue(cardTestView.isIndentationTriangleClosed(nodeIndex: 3))
        }
        
        step("When I unindent row4 and row6") {
            cardTestView.getTextNodeByIndex(nodeIndex: 3).tapInTheMiddle()
            shortcuts.shortcutActionInvokeRepeatedly(action: .unindent, numberOfTimes: 2)
            cardTestView.getIndentationTriangleAtNode(nodeIndex: 3).tapInTheMiddle()
            cardTestView.getTextNodeByIndex(nodeIndex: 4).tapInTheMiddle()
            shortcuts.shortcutActionInvoke(action: .unindent)
        }
        
        step("Then number of disclosure tirangles is 1 available for row 1 and all rows are visible") {
            XCTAssertEqual(cardTestView.getNumberOfDisclosureTriangles(), 1)
            XCTAssertTrue(cardTestView.isIndentationTriangleOpened(nodeIndex: 0))
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), "row1")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(1), "row2")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(2), "row3")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(3), "row4")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(4), "row6")
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(5), "row5")
        }
    }
    
    func testInsertLinkPopUp() {

        let addLinkView = AddLinkView()
        let webView = WebTestView()
        let textToAddLink = "Test Link"
        let urlAdded = "beamapp.co/"
        let textAppended = " Updated"
        let expectedBiDiLink = textToAddLink + textAppended
        
        launchAppAndOpenFirstNote()
        
        step("Given I add text in a note") {
            cardTestView.typeInCardNoteByIndex(noteIndex: 0, text: textToAddLink,  needsActivation: true)
        }
        
        step("When I access to Link editor") {
            shortcuts.shortcutActionInvoke(action: .selectAll)
            shortcuts.shortcutActionInvoke(action: .insertLink)
            addLinkView.waitForLinkEditorPopUpAppear()
        }
        
        step("Then Link URL is empty") {
            XCTAssertEqual(addLinkView.getLink(), emptyString)
        }
        
        step("When I add Link URL field") {
            addLinkView.getLinkElement().clickOnExistence()
            XCTAssertFalse(addLinkView.isCopyLinkIconDisplayed())
            addLinkView.getLinkElement().typeText(urlAdded)
        }
        
        step("And I modify title") {
            addLinkView.clickOnTitleCell(title: textToAddLink).typeText(textAppended)
            XCTAssertTrue(addLinkView.isCopyLinkIconDisplayed())
        }
        
        step("And I copy URL") {
            addLinkView.clickOnCopyLinkElement()
            XCTAssertTrue(addLinkView.isLinkCopiedLabelDisplayed())
        }
        
        step("Then Note is updated with link correctly inserted") {
            addLinkView.typeKeyboardKey(.enter)
            XCTAssertEqual(cardTestView.getCardNoteValueByIndex(0), expectedBiDiLink)
            cardTestView.openBiDiLink(expectedBiDiLink)
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 0), urlAdded)
        }
        
        step("And link is copied") {
            cardTestView.shortcutsHelper.shortcutActionInvoke(action: .newTab)
            cardTestView.shortcutsHelper.shortcutActionInvoke(action: .paste)
            cardTestView.typeKeyboardKey(.enter)
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertEqual(webView.getTabUrlAtIndex(index: 1), urlAdded)
        }
    }
}
