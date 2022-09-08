//
//  TabGroupUngroupTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 25/07/2022.
//

import Foundation
import XCTest

class TabGroupUngroupTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    
    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createTabGroupAndSwitchToWeb()
        }
    }
    
    func testTabGroupUngroup() throws {
        testrailId("C986")
        step("When I ungroup tabs") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupUngroup)
        }
        
        step("Then tabs are ungrouped") {
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertFalse(tabGroupMenu.isTabGroupDisplayed(index: 0))
        }
    }
    
    func testTabGroupUngroupWhenCollapsed() throws {
        testrailId("C986")
        step("When I collapse tab group") {
            tabGroupMenu.collapseTabGroup(index: 0)
        }
        
        step("Then group is collapsed") {
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
        
        step("And I ungroup tabs") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupUngroup)
        }
        
        step("Then tabs are ungrouped") {
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertFalse(tabGroupMenu.isTabGroupDisplayed(index: 0))
        }
    }
}
