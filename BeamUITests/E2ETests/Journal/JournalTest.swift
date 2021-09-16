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
        let numberOfScrolls = 10
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        let journalScrollView = journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)
        
        testRailPrint("Given I populate journal with data")
        helper.tapCommand(.logout)
        helper.tapCommand(.populateDBWithJournal)
        helper.restart()
        
        testRailPrint("When I scroll for \(numberOfScrolls) times")
        journalView.scroll(numberOfScrolls)
        
        testRailPrint("Then Journal scroll view still exists")
        XCTAssertTrue(journalScrollView.exists)
        
        testRailPrint("Given I remove all data from journal")
        helper.tapCommand(.destroyDB)
        helper.restart()
        
        testRailPrint("When I scroll for \(numberOfScrolls) times")
        journalView.scroll(numberOfScrolls)
        
        testRailPrint("Then Journal scroll view still exists")
        XCTAssertTrue(journalScrollView.exists)
    }
    
    
}
