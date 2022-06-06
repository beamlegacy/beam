//
//  NotesNavigationHistoryTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 26.05.2022.
//

import Foundation
import XCTest

class NotesNavigationHistoryTests: BaseTest {
    
    var noteView: CardTestView!
    
    private func assertJournalIsOpened() {
        XCTAssertTrue(JournalTestView()
                        .waitForJournalViewToLoad()
                        .isJournalOpened())
    }
    
    private func assertAllNotesIsOpened() {
        XCTAssertTrue(AllNotesTestView().waitForAllCardsViewToLoad())
    }
    
    private func assertNoteIsOpened() {
        XCTAssertTrue(noteView.waitForCardViewToLoad())
    }
    
    func testNotesNavigationHistory() {
        launchApp()
        
        step("GIVEN I open All notes and default note") {
            noteView = openFirstCardInAllCardsList()
        }
        
        step("THEN forward button is disabled and All Notes opened on Back button click"){
            XCTAssertFalse(noteView.button(WebViewLocators.Buttons.goForwardButton.accessibilityIdentifier).exists)
            noteView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).tapInTheMiddle()
            self.assertAllNotesIsOpened()
        }
        
        step("THEN Journal is opened on CMD+[ shortcuts click and Back button is disabled"){
            noteView.shortcutsHelper.shortcutActionInvoke(action: .browserHistoryBack)
            self.assertJournalIsOpened()
            XCTAssertFalse(noteView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).exists)
        }
        
        step("THEN All Notes is opened on navigation history forward button click"){
            noteView.button(WebViewLocators.Buttons.goForwardButton.accessibilityIdentifier).tapInTheMiddle()
            self.assertAllNotesIsOpened()
        }
        
        step("THEN Today's note is opened on CMD+] shortcuts call"){
            noteView.shortcutsHelper.shortcutActionInvoke(action: .browserHistoryForward)
            self.assertNoteIsOpened()
        }
        
        step("THEN All Notes is opened on Go menu -> Back option"){
            GoMenu().goBack()
            self.assertAllNotesIsOpened()
        }
        
        step("THEN Today's note is opened on Go menu -> Forward option"){
            GoMenu().goForward()
            self.assertNoteIsOpened()
        }
        
        //CMD+left/right arrow assertions to be implemented once BE-4244 is fixed
    }
    
}
