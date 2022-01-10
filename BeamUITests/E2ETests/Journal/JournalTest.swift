//
//  JournalTests.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class JournalTest: BaseTest {
    
    func testJournalScrollViewExistence() {
        //The test current takes about 5 mins to run due to populate DB with journal and doesn't actually test the functionality, more performance, to be refactored in terms of increase functionality coverage decreasing the time to run it
        //let numberOfScrolls = 10
        let journalView = launchApp()
        //let helper = BeamUITestsHelper(journalView.app)
        let journalScrollView = journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)
        //Currently it will test we land on Journal on the app launch
        testRailPrint("Then Journal scroll view exists")
        XCTAssertTrue(journalScrollView.waitForExistence(timeout: minimumWaitTimeout))
        
        testRailPrint("When I open All notes and restart the app")
        ShortcutsHelper().shortcutActionInvoke(action: .showAllCards)
        restartApp()
        
        testRailPrint("Then I still have Journal opened on the app start")
        XCTAssertTrue(journalScrollView.waitForExistence(timeout: minimumWaitTimeout))
        /*testRailPrint("Given I populate journal with data")
        helper.tapCommand(.logout)
        helper.tapCommand(.populateDBWithJournal)
        self.restartApp()
        
        testRailPrint("When I scroll for \(numberOfScrolls) times")
        journalView.scroll(numberOfScrolls)
        
        testRailPrint("Then Journal scroll view still exists")
        XCTAssertTrue(journalScrollView.exists)
        
        testRailPrint("Given I remove all data from journal")
        helper.tapCommand(.destroyDB)
        self.restartApp()
        
        testRailPrint("When I scroll for \(numberOfScrolls) times")
        journalView.scroll(1)
        
        testRailPrint("Then Journal scroll view still exists")
        XCTAssertTrue(journalScrollView.exists)*/
    }
    
    func testIfJournalIsEmptyByDefault() throws {
        let journalView = launchApp()
        testRailPrint("When the journal is first loaded the note is empty by default")
        journalView.waitForJournalViewToLoad()
        let beforeCardNotes = CardTestView().getCardNotesForVisiblePart()
        XCTAssertEqual(beforeCardNotes[0].value as? String, "")
    }

}
