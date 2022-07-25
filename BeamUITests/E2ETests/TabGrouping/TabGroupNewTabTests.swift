//
//  TabGroupNewTabTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 25/07/2022.
//

import Foundation
import XCTest

class TabGroupNewTabTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    
    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupNewTab() throws {
        
        step("When I add a tab to the group") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCollapse)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "5")
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
    }
    
    func testTabGroupNewTabWhenCollapsed() throws {
        
        step("When I collapse tab group") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCollapse)
        }
        
        step("Then Tab Group name contains the number of tabs") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "4")
        }
        
        step("When I add a tab to the group") {
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "5")
            tabGroupMenu.openFirstTabGroupMenu()
            tabGroupMenu.waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupExpand)
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
        }
    }
}
