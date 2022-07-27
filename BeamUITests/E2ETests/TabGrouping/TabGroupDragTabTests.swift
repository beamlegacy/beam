//
//  TabGroupDragTabTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 25/07/2022.
//

import Foundation
import XCTest

class TabGroupDragTabTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    
    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupDragTabOutside() throws {
        
        step("When I drag tab outside of the group") {
            webView.dragTabOutOfTheGroup(tabIndex: 3)
        }
        
        step("Then tabs are ungrouped") {
            tabGroupMenu.collapseFirstTabGroup()
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "3")
        }
    }
    
    func testTabGroupDragTabInside() throws {
        
        step("When I open a new tab") {
            uiMenu.loadUITestPageMedia()
        }
        
        step("Then tab is outside of the group") {
            tabGroupMenu.collapseFirstTabGroup()
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "4")
            tabGroupMenu.expandFirstTabGroup()
        }
        
        step("When I drag new tab inside of the group") {
            webView.dragDropTab(draggedTabIndexFromSelectedTab: 4, destinationTabIndexFromSelectedTab: 2)
        }
        
        step("Then tab is inside the group") {
            tabGroupMenu.collapseFirstTabGroup()
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "5")
        }
    }
}
