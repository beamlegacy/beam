//
//  AllNotesSortingTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 15.06.2022.
//

import Foundation
import XCTest

class AllNotesSortingTests: BaseTest {
    
    var helper: BeamUITestsHelper!
    var allNotesView: AllNotesTestView!
    var table: AllNotesTestTable!
    
    private func sortBy(_ column: AllNotesViewLocators.SortButtons) -> AllNotesTestTable {
        allNotesView
            .sortTableBy(column)
            .waitForAllNotesViewToLoad()
        return AllNotesTestTable()
    }
    
    private func assertTitleSort(descending: Bool) {
        table = sortBy(.title)
        for i in 1...table.numberOfVisibleItems-1 {
            
            let charTitle1 = table.rows[i].title.character(at: 0)!
            let charTitle2 = table.rows[i - 1].title.character(at: 0)!
            
            if descending {
                XCTAssertGreaterThanOrEqual(charTitle1, charTitle2)
            } else {
                XCTAssertLessThanOrEqual(charTitle1, charTitle2)
            }
            
            if charTitle1 == charTitle2 {
                if descending {
                    XCTAssertGreaterThanOrEqual(table.rows[i].title.character(at: 1)!, table.rows[i - 1].title.character(at: 1)!)
                } else {
                    XCTAssertLessThanOrEqual(table.rows[i].title.character(at: 1)!, table.rows[i - 1].title.character(at: 1)!)
                }
            }
        }
    }
    
    func testSortNotesByWordsAndLinks() {
        
        step("GIVEN I setup staging environment and open All cards") {
            helper = BeamUITestsHelper(setupStaging(withRandomAccount: true).app)
            helper.tapCommand(.create10Notes)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            shortcutHelper.shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
            allNotesView.waitForAllNotesViewToLoad()
        }
        
        step("THEN I successfully sort notes by Title descending") {
            assertTitleSort(descending: true)
        }
        
        step("THEN I successfully sort notes by Title ascending") {
            assertTitleSort(descending: false)
        }
        
        step("THEN I successfully sort notes by Words descending") {
            table = sortBy(.words)
            for i in 1...table.numberOfVisibleItems-1 {
                XCTAssertLessThanOrEqual(table.rows[i].words, table.rows[i - 1].words)
            }
        }
        
        step("THEN I successfully sort notes by Words ascending") {
            table = sortBy(.words)
            for i in 1...table.numberOfVisibleItems-1 {
                XCTAssertGreaterThanOrEqual(table.rows[i].words, table.rows[i - 1].words)
            }
        }
        
        step("THEN I successfully sort notes by Links descending") {
            table = sortBy(.links)
            for i in 1...table.numberOfVisibleItems-1 {
                XCTAssertLessThanOrEqual(table.rows[i].links, table.rows[i - 1].links)
            }
        }
        
        step("THEN I successfully sort notes by Links ascending") {
            table = sortBy(.links)
            for i in 1...table.numberOfVisibleItems-1 {
                XCTAssertGreaterThanOrEqual(table.rows[i].links, table.rows[i - 1].links)
            }
        }
    }
    
}
