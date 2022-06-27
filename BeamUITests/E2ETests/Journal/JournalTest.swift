//
//  JournalTests.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class JournalTest: BaseTest {
    
    let noteView = NoteTestView()
    
    func testJournalScrollViewExistence() {
        let journalView = launchApp()
        let journalScrollView = journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)

        step("Then Journal scroll view exists"){
            XCTAssertTrue(journalScrollView.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("When I open All notes and restart the app"){
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            restartApp()
        }

        step("Then I still have Journal opened on the app start"){
            XCTAssertTrue(journalScrollView.waitForExistence(timeout: BaseTest.minimumWaitTimeout))

        }
    }
    
    func testIfJournalIsEmptyByDefault() throws {
        let journalView = launchApp()
        step("When the journal is first loaded the note is empty by default"){
            journalView.waitForJournalViewToLoad()
            let beforeNoteNodes = noteView.getNoteNodesForVisiblePart()
            XCTAssertEqual(beforeNoteNodes[0].getStringValue(), emptyString)
        }
    }
}
