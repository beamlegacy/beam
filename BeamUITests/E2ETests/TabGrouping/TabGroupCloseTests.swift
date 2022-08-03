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
    let journalTestView = JournalTestView()
    
    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupClose() throws {

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
            journalTestView.waitForJournalViewToLoad()
            XCTAssertTrue(journalTestView.isJournalOpened())
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            XCTAssertTrue(journalTestView.isJournalOpened())
            XCTAssertTrue(OmniBoxTestView().getOmniBoxSearchField().exists)
        }
    }
}
