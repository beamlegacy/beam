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
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
            tabGroupMenu.collapseTabGroup(index: 0)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "5")
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
    }
    
    func testTabGroupNewTabWhenCollapsed() throws {
        
        step("When I collapse tab group") {
            tabGroupMenu.collapseTabGroup(index: 0)
        }
        
        step("Then Tab Group name contains the number of tabs") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "4")
        }
        
        step("When I add a tab to the group") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "5")
            tabGroupMenu.expandTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
        }
    }
}
