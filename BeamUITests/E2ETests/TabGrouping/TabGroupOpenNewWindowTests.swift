//
//  TabGroupOpenNewWindowTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 26/07/2022.
//

import Foundation
import XCTest

class TabGroupOpenNewWindowTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    
    override func setUp() {
        step("Given I have two tab groups") {
            super.setUp()
            uiMenu.invoke(.createTabGroupNamed)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            uiMenu.invoke(.createTabGroupNamed)
            tabGroupView.waitForTabGroupNameToBeDisplayed(tabGroupName: "Test1")
            tabGroupView.waitForTabGroupNameToBeDisplayed(tabGroupName: "Test2")
        }
    }
    
    func testTabGroupMoveOutsideWindow() throws {
        testrailId("C983")
        step("Then one window is opened with 8 tabs") {
            XCTAssertEqual(getNumberOfWindows(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(), 8)
        }
        
        step("When I open one tab group to another window") {
            tabGroupView.openTabGroupMenuWithName(tabGroupName: "Test1")
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupMoveNewWindow)
        }
        
        step("Then two windows are opened with 4 tabs each") {
            XCTAssertEqual(getNumberOfWindows(), 2)
            // We have two windows here
            XCTAssertEqual(getNumberOfTabInWindowIndex(index: 0), 4)
            XCTAssertEqual(getNumberOfTabInWindowIndex(index: 1), 4)
        }
    }
}
