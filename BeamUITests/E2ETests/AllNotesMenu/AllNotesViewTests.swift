//
//  AllCardsViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 22.09.2021.
//

import Foundation
import XCTest

class AllNotesViewTests: BaseTest {
    
    var allNotesView: AllNotesTestView!
    
    func testAllNotesView() throws {
        //The super simple test is just a beginning of All Notes view tests (better smth then nothing)
        //The implementation to be unblocked with BE-4181, BE-4211, BE-4212
        
        step ("GIVEN I open All notes") {
            launchAppWithArgument(self.uiTestModeLaunchArgument) //to be used for future account creation and publishing
            ShortcutsHelper().shortcutActionInvoke(action: .showAllNotes)
            allNotesView = AllNotesTestView()
        }
        
        step ("THEN by default row shows correct number of words and links") {
            let table = AllNotesTestTable()
            XCTAssertEqual(table.rows[0].words, 0)
            XCTAssertEqual(table.rows[0].links, 0)
        }
        
        step ("THEN I can switch between views successfully") {
            allNotesView.openTableView(.privateNotes)
            XCTAssertEqual(allNotesView.getViewCountValue(), 1)
            
            allNotesView.openTableView(.publishedNotes)
            XCTAssertEqual(allNotesView.getViewCountValue(), 0)
            
            allNotesView.openTableView(.profileNotes)
            XCTAssertEqual(allNotesView.getViewCountValue(), 0)
        }
    }
    
    func testTableComparisonFunctionality() {
        let result = RowAllNotesTestTable("xyz", 2, 1, "abc").isEqualTo(RowAllNotesTestTable("abc", 1, 2, "xyz"))
        XCTAssertFalse(result.0, result.1)
    }
    
}
