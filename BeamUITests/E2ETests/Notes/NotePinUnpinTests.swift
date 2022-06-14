//
//  NotePinUnpinTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 09/06/2022.
//

import Foundation
import XCTest

class NotePinUnpinTests: BaseTest {
    
    let noteTestView = NoteTestView()
    let allNotesView = AllNotesTestView()
    let todaysNoteName = DateHelper().getTodaysDateString(.allNotesViewDates)
    
    func testPinUnpinTest() {
        let noteSwitcherButton = noteTestView.app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)' AND value = '\(todaysNoteName)'"))
        
        launchAppAndOpenFirstNote()

        step("Given I pin a note") {
            noteTestView.pinUnpinNote()
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin the note") {
            noteTestView.pinUnpinNote()
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
    
    func testMax5PinnedNotes() {
        let journalView = launchApp()
        
        step("Given I pin 6 notes") {
            BeamUITestsHelper(journalView.app).tapCommand(.create10Notes)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            for i in 0...5 {
                allNotesView.openMenuForSingleNote(i)
                allNotesView.selectActionInMenu(.pinNote)
            }
        }
        
        step("Then alert is displayed") {
            XCTAssertTrue(XCUIApplication().staticTexts[AlertViewLocators.StaticTexts.fivePinnedNotesMax.accessibilityIdentifier].exists)
            XCTAssertTrue(XCUIApplication().staticTexts[AlertViewLocators.StaticTexts.tooManyPinnedNotes.accessibilityIdentifier].exists)
            AlertTestView().okClick()
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 5)
            
        }
        
    }
    
    func testShortcutPinNote() {
        let noteSwitcherButton = noteTestView.app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)' AND value = '\(todaysNoteName)'"))
        
        launchAppAndOpenFirstNote()
        
        step("Given I pin a note with shortcut") {
            shortcutHelper.shortcutActionInvoke(action: .pinUnpinNote)
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin the note with shortcut") {
            shortcutHelper.shortcutActionInvoke(action: .pinUnpinNote)
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
    
    func testPinFromAllNotes() {
        let noteSwitcherButton = noteTestView.app.buttons.element(matching: NSPredicate(format: "identifier = '\(ToolbarLocators.Buttons.noteSwitcher.accessibilityIdentifier)' AND value = '\(todaysNoteName)'"))
        
        step ("Given I navigate to All Note") {
            launchApp()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
        
        step ("Then I can pin a note from All Notes") {
            allNotesView.openMenuForSingleNote(0)
            XCTAssertTrue(allNotesView.isElementAvailableInSingleNoteMenu(AllNotesViewLocators.MenuItems.pinNote))
            allNotesView.typeKeyboardKey(.escape) // close the menu
            allNotesView.triggerAllNotesMenuOptionAction(.pinNote)
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin a note from All Notes") {
            allNotesView.openMenuForSingleNote(0)
            XCTAssertTrue(allNotesView.isElementAvailableInSingleNoteMenu(AllNotesViewLocators.MenuItems.unpinNote))
            allNotesView.typeKeyboardKey(.escape) // close the menu
            allNotesView.triggerAllNotesMenuOptionAction(.unpinNote)
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteSwitcherButton.exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
}
