//
//  NoteEditorTests.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class NoteEditorTests: BaseTest {
    
    func testTypeTextInNote() {
        let numberOfCharsToDelete = 3
        let journalView = launchApp()
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        let firstJournalEntry = journalView.getNoteByIndex(1)
        firstJournalEntry.clear()
        
        let dateFormatter = DateFormatter()
        // some CI macs don't like to input ":"
        dateFormatter.dateFormat = "dd-MM-yyyy HH-mm Z"
        let textInput = "Testing typing date \(dateFormatter.string(from: Date()))_ok"
        
        testRailPrint("Given I type slowly in the journal note: \(textInput)")
        CardTestView().getCardNotesForVisiblePart().first?.click()
        journalView.app.typeSlowly(textInput, everyNChar: 1)
        
        testRailPrint("Then note displays typed text: \(textInput)")
        XCTAssertEqual(firstJournalEntry.value as? String, textInput)
        
        testRailPrint("When I delete \(numberOfCharsToDelete) last chars")
        journalView.typeKeyboardKey(.delete, numberOfCharsToDelete)
        
        let index = textInput.firstIndex(of: "_")!
        let editedText = String(textInput[..<index])

        testRailPrint("Then note displays edited text: \(editedText)")
        XCTAssertEqual(firstJournalEntry.value as? String, editedText)
    }
    
    func testSlashCommandsView() {
        let journalView = launchApp()
        let contextMenuTriggerKey = "/"
        BeamUITestsHelper(journalView.app).tapCommand(.destroyDB)
        launchApp()
        
        testRailPrint("Given I type \(contextMenuTriggerKey) char")
        CardTestView().getCardNotesForVisiblePart().first?.click()
        let firstJournalEntry = journalView.getNoteByIndex(1)
        firstJournalEntry.tapInTheMiddle()
        firstJournalEntry.clear()
        journalView.app.typeText(contextMenuTriggerKey)
        
        testRailPrint("Then Context menu is displayed")
        let contextMenuView = ContextMenuTestView(key: NoteViewLocators.Groups.slashContextMenu.accessibilityIdentifier)
        XCTAssertTrue(contextMenuView.menuElement().waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("Then Context menu items exist, enabled and hittable")
        for item in NoteViewLocators.ContextMenuItems.allCases {
            let identifier = item.accessibilityIdentifier
            let element = contextMenuView.staticText(identifier).firstMatch
            XCTAssertTrue(element.exists && element.isEnabled && element.isHittable, "element \(identifier) couldn't be reached")
        }
        
        testRailPrint("When I press delete button")
        journalView.typeKeyboardKey(.delete)
        
        testRailPrint("Then Context menu is NOT displayed")
        XCTAssertTrue(WaitHelper().waitForDoesntExist(contextMenuView.menuElement()))
        
        journalView.app.typeText(contextMenuTriggerKey + "bol")
        let boldMenuItem = contextMenuView.staticText(NoteViewLocators.ContextMenuItems.boldItem.accessibilityIdentifier)
        
        testRailPrint("Then Bold context menu item is displayed")
        XCTAssertTrue(boldMenuItem.waitForExistence(timeout: implicitWaitTimeout))
        
        testRailPrint("When I press return button")
        journalView.typeKeyboardKey(.enter)
        
        testRailPrint("Then Bold context menu item is NOT displayed")
        XCTAssertTrue(WaitHelper().waitForDoesntExist(boldMenuItem))
    }
}
