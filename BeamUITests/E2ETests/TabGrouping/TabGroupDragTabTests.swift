//
//  TabGroupDragTabTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 25/07/2022.
//

import Foundation
import XCTest

class TabGroupDragTabTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    
    override func setUp() {
        step("Given I have a tab group") {
            super.setUp()
            createTabGroupAndSwitchToWeb()
        }
    }
    
    func testTabGroupDragTabOutside() {
        testrailId("C978")
        step("When I drag tab outside of the group") {
            webView.dragTabToOmniboxIconArea(tabIndex: 3)
        }
        
        step("Then tabs are ungrouped") {
            tabGroupView.collapseTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "3")
        }
    }
    
    func testTabGroupDragTabInside() {
        testrailId("C977")
        step("When I open a new tab after group was formed") {
            uiMenu.invoke(.loadUITestPagePassword) // loading a page that is not auto grouped
        }
        
        step("Then tab is outside of the group") {
            tabGroupView.collapseTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "4")
            tabGroupView.expandTabGroup(index: 0)
        }
        
        step("When I drag new tab inside of the group") {
            webView.dragDropTab(draggedTabIndexFromSelectedTab: 4, destinationTabIndexFromSelectedTab: 2)
        }
        
        step("Then tab is inside the group") {
            tabGroupView.collapseTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), "5")
        }
    }
    
    private func createTabGroupManuallyForTab(index: Int) {
        step("When I create tab group manually") {
            webView
                .openTabMenu(tabIndex: index)
                .selectTabMenuItem(.createTabGroup)
        }
    }
    
    func testDragTabGroupOutsideWindow() {
        testrailId("C1052")
        // blocked by https://linear.app/beamapp/issue/BE-4720/draggable-tab-groups
        let tabGroupsTitlesAfterDragAndDrop = [
            "Test1",
            "4",
            "Test2"
        ]
        
        step("GIVEN I add other tab groups"){
            
            // Delete this part when https://linear.app/beamapp/issue/BE-4720/draggable-tab-groups is fully fixed
            uiMenu.invoke(.loadUITestPagePassword)
            uiMenu.invoke(.loadUITestPageMedia)
            tabGroupView.collapseTabGroup(index: 0)
            createTabGroupManuallyForTab(index: 0)
            createTabGroupManuallyForTab(index: 1)
            
            tabGroupView.openTabGroupMenu(index: 1)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: tabGroupsTitlesAfterDragAndDrop[0])
            
            tabGroupView.openTabGroupMenu(index: 2)
                .waitForMenuToBeDisplayed()
            tabGroupView.setTabGroupName(tabGroupName: tabGroupsTitlesAfterDragAndDrop[2])
            
            // Restore this part when https://linear.app/beamapp/issue/BE-4720/draggable-tab-groups is fully fixed
//            uiMenu.invoke(.createTabGroupNamed)
//            uiMenu.invoke(.createTabGroupNamed)
//            tabGroupView.collapseTabGroup(index: 0)
        }

        step("THEN the tab groups order is successfully changed on drag'n'drop"){
            tabGroupView.dragDropTabGroup(draggedTabGroupIndexFromSelectedTab: 0, destinationTabGroupIndexFromSelectedTab: 2)
            XCTAssertTrue(tabGroupView.areTabGroupsInCorrectOrder(tabGroups: tabGroupsTitlesAfterDragAndDrop))
        }
        
        step("AND new window is opened when drag'n'drop a tab group outside the browser"){
            tabGroupView.dragAndDropTabGroupToElement(tabGroupIndex: 2, elementToDragTo: webView.button(WebViewLocators.Buttons.goToJournalButton.accessibilityIdentifier))
            XCTAssertTrue(waitForQueryCountEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getWindowsQuery()), "Second window wasn't opened during \(BaseTest.implicitWaitTimeout) seconds timeout")
            XCTAssertEqual(self.getNumberOfTabGroupInWindowIndex(index: 0), 1)
            XCTAssertEqual(self.getNumberOfTabGroupInWindowIndex(index: 1), 2)
        }
    }
    
}
