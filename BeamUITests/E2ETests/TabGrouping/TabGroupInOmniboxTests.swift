//
//  TabGroupInOmniboxTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 16/08/2022.
//

import Foundation
import XCTest

class TabGroupInOmniboxTests: BaseTest {
    
    let tabGroupMenu = TabGroupMenuView()
    let omniboxView = OmniBoxTestView()
    let openAllTabsLabel = "Open All Tabs"
    let tabGroupUnamedSuffix = " & 3 more"
    let tabGroupNamed = "Test1"

    private func createAndCaptureTabGroup (named: Bool){
        if named {
            uiMenu.createTabGroupNamed()
        } else {
            uiMenu.createTabGroup()

        }
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        tabGroupMenu.captureTabGroup(index: 0)
    }
    override func setUp() {
        launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
    }
    
    func testTabGroupNavigationInOmnibox() throws {
        
        let autocompleteResults = [
            openAllTabsLabel,
            uiTestPageOne,
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageFour
        ]
        
        step("Given I capture an unnamed tab group") {
            createAndCaptureTabGroup(named: false)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("Then tab group is displayed in omnibox") {
            omniboxView.searchInOmniBox("Point", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), uiTestPageOne + tabGroupUnamedSuffix)
        }
        
        step("When I click on tab group") {
            omniboxView.getAutocompleteResults().firstMatch.clickInTheMiddle()
        }
        
        step("Then tab group details are displayed") {
            _ = omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count)
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, 5)
            XCTAssertTrue(omniboxView.areAutocompleteResultsInCorrectOrder(results: autocompleteResults))
        }
        
        step("When I press Escape") {
            omniboxView.typeKeyboardKey(.escape)
        }
        
        step("Then omnibox is displayed with search autocomplete results") {
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), uiTestPageOne + tabGroupUnamedSuffix)
        }
        
        step("When I press Enter") {
            omniboxView.typeKeyboardKey(.enter)
        }
        
        step("Then tab group details are displayed") {
            _ = omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count)
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, 5)
            XCTAssertTrue(omniboxView.areAutocompleteResultsInCorrectOrder(results: autocompleteResults))
        }
    }
    
    func testOpenAllTabs() throws {
        
        let tabTitles = [
            uiTestPageOne,
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageFour
        ]
        
        step("Given I capture an unnamed tab group") {
            createAndCaptureTabGroup(named: false)
            tabGroupMenu.closeTabGroup(index: 0)
        }
        
        step("When I reopen all tabs") {
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.typeKeyboardKey(.enter)
            _ = omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 5)
            omniboxView.getAutocompleteResults().firstMatch.clickInTheMiddle()
        }
        
        step("Then all tabs are reopened in correct order") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(webView.areTabsInCorrectOrder(tabs: tabTitles))
        }
        
        step("And tab group name is correct") {
            XCTAssertEqual(tabGroupMenu.getTabGroupName(), uiTestPageOne + tabGroupUnamedSuffix)
        }
    }
    
    func testOpenIndividualTab() throws {
        
        step("Given I capture an unnamed tab group") {
            createAndCaptureTabGroup(named: false)
            tabGroupMenu.closeTabGroup(index: 0)
        }
        
        step("When I open one tab") {
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.typeKeyboardKey(.enter)
            _ = omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 5)
            omniboxView.getAutocompleteResults().element(boundBy: 1).clickInTheMiddle()
        }
        
        step("Then only the selected tab is opened") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), uiTestPageOne)
        }
    }
    
    func testTabGroupNamedInOmnibox() throws {
        
        step("Given I capture a named tab group") {
            createAndCaptureTabGroup(named: true)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("Then tab group name is displayed in omnibox") {
            omniboxView.searchInOmniBox("Test", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), tabGroupNamed)
        }
    }
}
