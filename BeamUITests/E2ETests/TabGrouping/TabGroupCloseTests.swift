//
//  TabGroupCloseTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 19/07/2022.
//

import Foundation
import XCTest

class TabGroupCloseTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    var journalTestView = JournalTestView()
    
    override func setUp() {
        step("Given I have a tab group") {
            testrailId("C936")
            super.setUp()
            createTabGroupAndSwitchToWeb()
        }
    }
    
    func testTabGroupClose() {
        testrailId("C987")
        step("When I open Tab Group Menu") {
            tabGroupView.openTabGroupMenu(index: 0)
        }
        
        step("Then Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupView.waitForMenuToBeDisplayed())
        }
        
        step("When I close the tab group") {
            tabGroupView.clickTabGroupMenu(.tabGroupCloseGroup)
        }
        
        step("Then tab group is closed") {
            XCTAssertTrue(journalTestView
                .waitForJournalViewToLoad()
                .isJournalOpened())
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            XCTAssertTrue(journalTestView.isJournalOpened())
            XCTAssertTrue(OmniBoxTestView().getOmniBoxSearchField().exists)
        }
    }
}
