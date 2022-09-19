//
//  TabGroupNewTabTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 25/07/2022.
//

import Foundation
import XCTest

class TabGroupNewTabTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    
    override func setUp() {
        step("Given I have a tab group") {
            super.setUp()
            createTabGroupAndSwitchToWeb()
        }
    }
    
    func testTabGroupNewTab() throws {
        testrailId("C982")
        step("When I add a tab to the group") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
            tabGroupView.collapseTabGroup(index: 0)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "5")
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
    }
    
    func testTabGroupNewTabWhenCollapsed() throws {
        testrailId("C982")
        step("When I collapse tab group") {
            tabGroupView.collapseTabGroup(index: 0)
        }
        
        step("Then Tab Group name contains the number of tabs") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "4")
        }
        
        step("When I add a tab to the group") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupNewTab)
        }
        
        step("Then Tab Group contains one more tab") {
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "5")
            tabGroupView.expandTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 5)
        }
    }
}
