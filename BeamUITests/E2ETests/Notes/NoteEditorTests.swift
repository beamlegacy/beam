//
//  NoteEditorTests.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class NoteEditorTests: BaseTest {
    
    let cardTestView = CardTestView()
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
    
    func testTypeTextInNote() {
        let journalView = launchApp()
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        let helper = ShortcutsHelper()
        let firstJournalEntry = journalView.getNoteByIndex(1)
        firstJournalEntry.clear()
        
        testRailPrint("Then note displays typed text correctly")
        cardTestView.getCardNotesForVisiblePart().first?.click()
        journalView.app.typeText(texts[0])
        XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[0])
        
        testRailPrint("Then note displays typed text from the beginning of the note correctly")
        helper.shortcutActionInvoke(action: .beginOfNote)
        journalView.app.typeText(texts[1])
        XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[1] + texts[0])
        
        testRailPrint("Then note displays replaced typed text correctly")
        helper.shortcutActionInvoke(action: .selectAll)
        journalView.app.typeText(texts[2])
        XCTAssertEqual(journalView.getElementStringValue(element:firstJournalEntry), texts[2])
        
        journalView.typeKeyboardKey(.enter)
        testRailPrint("Then second note displays changed text correctly")
        let expectedResult = BeamUITestsHelper(journalView.app).typeAndEditHardcodedText(journalView)
        XCTAssertEqual(journalView.getElementStringValue(element:journalView.getNoteByIndex(2)), expectedResult)
    }
    
    func testSlashCommandsView() {
        let journalView = launchApp()
        let contextMenuTriggerKey = "/"
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        
        testRailPrint("Given I type \(contextMenuTriggerKey) char")
        cardTestView.getCardNotesForVisiblePart().first?.click()
        let firstJournalEntry = journalView.getNoteByIndex(1)
        firstJournalEntry.tapInTheMiddle()
        firstJournalEntry.clear()
        let contextMenuView = cardTestView.triggerContextMenu(key:  NoteViewLocators.Groups.contextMenu.accessibilityIdentifier)
        
        testRailPrint("Then Context menu is displayed")
        XCTAssertTrue(contextMenuView.menuElement().waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("Then Context menu items exist, enabled and hittable")
        for item in NoteViewLocators.SlashContextMenuItems.allCases {
            let identifier = item.accessibilityIdentifier
            let element = contextMenuView.staticText(identifier).firstMatch
            XCTAssertTrue(element.exists && element.isEnabled && element.isHittable, "element \(identifier) couldn't be reached")
        }
        
        testRailPrint("When I press delete button")
        journalView.typeKeyboardKey(.delete)
        
        testRailPrint("Then Context menu is NOT displayed")
        XCTAssertTrue(WaitHelper().waitForDoesntExist(contextMenuView.menuElement()))
        
        journalView.app.typeText(contextMenuTriggerKey + "bol")
        let boldMenuItem = contextMenuView.staticText(NoteViewLocators.SlashContextMenuItems.boldItem.accessibilityIdentifier)
        
        testRailPrint("Then Bold context menu item is displayed")
        XCTAssertTrue(boldMenuItem.waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I press return button")
        journalView.typeKeyboardKey(.enter)
        
        testRailPrint("Then Bold context menu item is NOT displayed")
        XCTAssertTrue(WaitHelper().waitForDoesntExist(boldMenuItem))
    }
}
