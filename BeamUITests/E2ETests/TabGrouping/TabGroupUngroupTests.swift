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
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupUngroup() throws {
        
        step("When I ungroup tabs") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupUngroup)
        }
        
        step("Then tabs are ungrouped") {
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(tabGroupMenu.doesTabGroupExist())
        }
    }
    
    func testTabGroupUngroupWhenCollapsed() throws {
        
        step("When I collapse tab group") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCollapse)
        }
        
        step("Then group is collapsed") {
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
        
        step("And I ungroup tabs") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupUngroup)
        }
        
        step("Then tabs are ungrouped") {
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(tabGroupMenu.doesTabGroupExist())
        }
    }
}
