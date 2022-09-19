//
//  TabGroupNameTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 13/07/2022.
//

import Foundation
import XCTest

class TabGroupNameTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    let tabGroupName = "Tab Group Name"
    let tabGroupNameSpecialChars = "+-.,!@#$%^&*();\\/|<>\"\'"
    let expectedTabGroupName = "4"
    
    override func setUp() {
        step("Given I have a tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createTabGroupAndSwitchToWeb()
        }
    }
    
    func testTabGroupName() throws {
        testrailId("C979")
        step("When I open Tab Group Menu") {
            tabGroupView.openTabGroupMenu(index: 0)
        }
        
        step("Then Tab Group Menu is displayed") {
            XCTAssertTrue(tabGroupView.waitForMenuToBeDisplayed())
        }
        
        step("When I set a tab group name") {
            tabGroupView.setTabGroupName(tabGroupName: tabGroupName)
        }
        
        step("Then tab group name is set") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), tabGroupName)
        }
        
        step("When I delete tab group name") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.deleteTabGroupName()
        }
        
        step("Then tab group name is unset") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), emptyString)
        }
    }
    
    func testTabGroupNameCollapsed() throws {
        testrailId("C985")
        step("When I collapse tab group") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupCollapse)
        }
        
        step("Then Tab Group name contains the number of tabs") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), expectedTabGroupName)
        }
        
        step("When I set a tab group name") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: tabGroupName)
        }
        
        step("Then tab group name is set and contains the number of tabs") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), tabGroupName + " (\(expectedTabGroupName))")
        }
        
        step("When I delete tab group name") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.deleteTabGroupName()
        }

        step("Then tab group name is unset but we still see tab group number") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), expectedTabGroupName)
        }
    }
    
    func testTabGroupNameSpecialChar() throws {
        testrailId("C979")
        step("When I set a tab group name with special chars") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: tabGroupNameSpecialChars)
        }
        
        step("Then tab group name is set") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), tabGroupNameSpecialChars)
        }
    }

    func testTabGroupRestoration() {
        testrailId("C979")
        step("When I restart the app") {
            restartApp(storeSessionWhenTerminated: true)
        }

        step("Then the tab group is restored") {
            XCTAssertTrue(tabGroupView.getTabGroupElementIndex(index: 0).waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step("When I collapse tab group, set a tab group name and restart the app") {
            tabGroupView.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.clickTabGroupMenu(.tabGroupCollapse)
                .openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: tabGroupName)

            restartApp(storeSessionWhenTerminated: true)
        }

        step("Then tab group name is set and contains the number of tabs") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), tabGroupName + " (\(expectedTabGroupName))")
        }
    }
}
