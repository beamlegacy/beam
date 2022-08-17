//
//  TabGroupManualTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 02/08/2022.
//

import Foundation
import XCTest

class TabGroupManualTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let tabGroupUnnamed = "”Point And Shoot Test Fixt…”"
    let tabGroupNamed = "Tab Group Name"

    
    override func setUp() {
        step("Given I open multiple pages") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            uiMenu.loadUITestPage3()
        }
    }
    
    func testCreateManualGroup() throws {
        
        step("Then tab group is not created") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
            XCTAssertFalse(tabGroupMenu.isTabGroupDisplayed(index: 0))
        }
        
        step("When I create tab group manually") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.createTabGroup)
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
        }
        
        step("Then tab group is created") {
            XCTAssertTrue(tabGroupMenu.isTabGroupDisplayed(index: 0))
            tabGroupMenu.clickTabGroupCapsule(index: 0)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "1")
            tabGroupMenu.clickTabGroupCapsule(index: 0)
        }
    }
    
    func testAddOtherTabToGroup() throws {
        
        step("Then Add to group option is not available if group does not exist") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 0).isTabMenuOptionDisplayed(.addToGroup))
            webView.typeKeyboardKey(.escape)
            XCTAssertFalse(webView.openTabMenu(tabIndex: 1).isTabMenuOptionDisplayed(.addToGroup))
            webView.typeKeyboardKey(.escape)
            XCTAssertFalse(webView.openTabMenu(tabIndex: 2).isTabMenuOptionDisplayed(.addToGroup))
            webView.typeKeyboardKey(.escape)
        }
        
        step("When I create tab group manually") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.createTabGroup)
        }
        
        step("Then Add to group option is available on tabs not grouped") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 0).isTabMenuOptionDisplayed(.addToGroup))
            XCTAssertTrue(webView.isTabMenuOptionDisplayed(.ungroup))
            webView.typeKeyboardKey(.escape)
            XCTAssertTrue(webView.openTabMenu(tabIndex: 1).isTabMenuOptionDisplayed(.addToGroup))
            webView.typeKeyboardKey(.escape)
            XCTAssertTrue(webView.openTabMenu(tabIndex: 2).isTabMenuOptionDisplayed(.addToGroup))
            webView.typeKeyboardKey(.escape)
        }
        
        step("When I add another tab to the unnamed group") {
            webView.openTabMenu(tabIndex: 1).selectTabMenuItem(.addToGroup)
            app.menuItems[tabGroupUnnamed].clickInTheMiddle()
        }
        
        step("Then tab is added to the group") {
            XCTAssertTrue(tabGroupMenu.isTabGroupDisplayed(index: 0))
            tabGroupMenu.clickTabGroupCapsule(index: 0)
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), "2")
            tabGroupMenu.clickTabGroupCapsule(index: 0)
        }
        
        step("And unnamed tab group is updated") {
            webView.openTabMenu(tabIndex: 2).selectTabMenuItem(.addToGroup)
            XCTAssertTrue(app.menuItems[tabGroupUnnamed + " & 1 more"].exists)
        }
    }
    
    func testAddOtherTabToNamedGroup() throws {
        
        step("When I create tab group manually and name it") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.createTabGroup)
            tabGroupMenu.waitForTabGroupToBeDisplayed(index: 0)
            tabGroupMenu.openTabGroupMenu(index: 0)
                .waitForMenuToBeDisplayed()
            tabGroupMenu.setTabGroupName(tabGroupName: tabGroupNamed)
        }
        
        step("Then Add to group option is mentioning the correct name") {
            webView.openTabMenu(tabIndex: 2).selectTabMenuItem(.addToGroup)
            XCTAssertTrue(app.menuItems[tabGroupNamed].exists)
        }
    }
    
    func testUngroupManualTabGroupOneTab() throws {
        
        step("When I create tab group manually and name it") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.createTabGroup)
        }
        
        step("Then I can ungroup it") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.ungroup)
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
            XCTAssertFalse(tabGroupMenu.isTabGroupDisplayed(index: 0))
        }
    }
    
    func testCreateMultipleManualTabGroup() throws {
        
        step("When I create tab group manually and name it") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.createTabGroup)
            webView.openTabMenu(tabIndex: 1).selectTabMenuItem(.createTabGroup)
        }
        
        step("Then I have multiple groups") {
            XCTAssertEqual(tabGroupMenu.getTabGroupCount(), 2)
        }
    }
}
