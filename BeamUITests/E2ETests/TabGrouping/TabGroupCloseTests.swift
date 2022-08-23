//
//  TabGroupCloseTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 19/07/2022.
//

import Foundation
import XCTest

class TabGroupCloseTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    var journalTestView: JournalTestView!
    
    override func setUp() {
        step("Given I have a tab group") {
            journalTestView = launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            testrailId("C936")
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupClose() {
        testrailId("C987")
        step("When I open Tab Group Menu") {
            tabGroupMenu.openTabGroupMenu(index: 0)
        }
        
        step("Then Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupMenu.waitForMenuToBeDisplayed())
        }
        
        step("When I close the tab group") {
            tabGroupMenu.clickTabGroupMenu(.tabGroupCloseGroup)
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
