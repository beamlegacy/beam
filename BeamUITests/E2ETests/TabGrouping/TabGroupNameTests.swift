//
//  TabGroupNameTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 13/07/2022.
//

import Foundation
import XCTest

class TabGroupNameTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let tabGroupName = "Tab Group Name"
    let tabGroupNameSpecialChars = "+-.,!@#$%^&*();\\/|<>\"\'"

    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
    }
    
    func testTabGroupName() throws {

        step("When I open Tab Group Menu") {
            tabGroupMenu.openTabGroupMenu(index: 0)
        }
        
        step("Then Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupMenu.waitForMenuToBeDisplayed())
        }
        
        step("When I set a tab group name") {
            tabGroupMenu.setTabGroupName(tabGroupName: tabGroupName)
        }
        
        step("Then tab group name is set") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), tabGroupName)
        }
        
        step("When I delete tab group name") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.deleteTabGroupName()
        }
        
        step("Then tab group name is unset") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), emptyString)
        }
    }
    
    func testTabGroupNameCollapsed() throws {

        step("When I collapse tab group") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCollapse)
        }
        
        step("Then Tab Group name contains the number of tabs") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "4")
        }
        
        step("When I set a tab group name") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.setTabGroupName(tabGroupName: tabGroupName)
        }
        
        step("Then tab group name is set and contains the number of tabs") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), tabGroupName + " (4)")
        }
        
        step("When I delete tab group name") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.deleteTabGroupName()
        }

        step("Then tab group name is unset but we still see tab group number") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "4")
        }
    }
    
    func testTabGroupNameSpecialChar() throws {

        step("When I set a tab group name with special chars") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.setTabGroupName(tabGroupName: tabGroupNameSpecialChars)

        }
        
        step("Then tab group name is set") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), tabGroupNameSpecialChars)
        }
    }

    func testTabGroupRestoration() throws {
        step("When I restart the app") {
            restartApp(storeSessionWhenTerminated: true)
        }

        step("Then the tab group is restored") {
            XCTAssertTrue(tabGroupMenu.getTabGroupElementIndex(index: 0).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I collapse tab group, set a tab group name and restart the app") {
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.clickTabGroupMenu(.tabGroupCollapse)
                .openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.setTabGroupName(tabGroupName: tabGroupName)

            restartApp(storeSessionWhenTerminated: true)
        }

        step("Then tab group name is set and contains the number of tabs") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), tabGroupName + " (4)")
        }
    }
}
