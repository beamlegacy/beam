//
//  TabGroupOpenNewWindowTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 26/07/2022.
//

import Foundation
import XCTest

class TabGroupOpenNewWindowTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    
    override func setUp() {
        step("Given I have two tab groups") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroupNamed()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            uiMenu.createTabGroupNamed()
            tabGroupMenu.waitForTabGroupNameToBeDisplayed(tabGroupName: "Test1")
            tabGroupMenu.waitForTabGroupNameToBeDisplayed(tabGroupName: "Test2")
        }
    }
    
    func testTabGroupMoveOutsideWindow() throws {
        
        step("Then one window is opened with 8 tabs") {
            XCTAssertEqual(getNumberOfWindows(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(), 8)
        }
        
        step("When I open one tab group to another window") {
            tabGroupMenu.openTabGroupMenuWithName(tabGroupName: "Test1")
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupMoveNewWindow)
        }
        
        step("Then two windows are opened with 4 tabs each") {
            XCTAssertEqual(getNumberOfWindows(), 2)
            // We have two windows here
            XCTAssertEqual(getNumberOfTabInWindowIndex(index: 0), 4)
            XCTAssertEqual(getNumberOfTabInWindowIndex(index: 1), 4)
        }
    }
}
