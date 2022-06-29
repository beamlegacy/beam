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
        
        launchAppAndOpenFirstNote()

        step("Given I pin a note") {
            noteTestView.pinUnpinNote()
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin the note") {
            noteTestView.pinUnpinNote()
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
    
    func testMax5PinnedNotes() {
        
        step("Given I pin 6 notes") {
            launchApp()
            uiMenu.create10Notes()
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
        
        launchAppAndOpenFirstNote()
        
        step("Given I pin a note with shortcut") {
            shortcutHelper.shortcutActionInvoke(action: .pinUnpinNote)
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin the note with shortcut") {
            shortcutHelper.shortcutActionInvoke(action: .pinUnpinNote)
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
    
    func testPinFromAllNotes() {
        
        step ("Given I navigate to All Note") {
            launchApp()
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
        }
        
        step ("When I pin a note from All Notes") {
            allNotesView.openMenuForSingleNote(0)
                        .menuItem(AllNotesViewLocators.MenuItems.pinNote.accessibilityIdentifier).clickOnExistence()
        }
        
        step("Then note is correctly pinned") {
            XCTAssertTrue(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 1)
        }
        
        step("When I unpin a note from All Notes") {
            allNotesView.openMenuForSingleNote(0)
                        .menuItem(AllNotesViewLocators.MenuItems.unpinNote.accessibilityIdentifier).clickOnExistence()
        }
        
        step("Then note is correctly unpinned") {
            XCTAssertFalse(noteTestView.getNoteSwitcherButton(noteName: todaysNoteName).exists)
            XCTAssertEqual(noteTestView.getNumberOfPinnedNotes(), 0)
        }
    }
}
