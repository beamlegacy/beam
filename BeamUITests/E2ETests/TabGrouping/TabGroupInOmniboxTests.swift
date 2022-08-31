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
    let shareGroup = "Share Tab Group"
    let deleteGroup = "Delete Tab Group"
    let tabGroupUnamedSuffix = " & 3 more"
    let tabGroupNamed = "Test1"

    private func createAndCaptureTabGroup (named: Bool){
        if named {
            uiMenu.createTabGroupNamed()
        } else {
            uiMenu.createTabGroup()
        }
        shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        tabGroupMenu.waitForTabGroupToBeDisplayed(index: 0)
        tabGroupMenu.captureTabGroup(index: 0)
    }
    
    func testTabGroupNavigationInOmnibox() throws {
        testrailId("C1057")
        let autocompleteResults = [
            openAllTabsLabel,
            uiTestPageOne,
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageFour,
            shareGroup,
            deleteGroup
        ]
        
        testrailId("C1148")
        step("Given I capture an unnamed tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createAndCaptureTabGroup(named: false)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("Then tab group is displayed in omnibox") {
            omniboxView.searchInOmniBox("Point", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), uiTestPageOne + tabGroupUnamedSuffix)
        }
        
        step("When I click on tab group") {
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnamedSuffix)
        }
        
        step("Then tab group details are displayed") {
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count))
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, autocompleteResults.count)
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
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count))
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, autocompleteResults.count)
            XCTAssertTrue(omniboxView.areAutocompleteResultsInCorrectOrder(results: autocompleteResults))
        }
    }
    
    func testOpenAllTabs() throws {
        testrailId("C1058")
        let tabTitles = [
            uiTestPageOne,
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageFour
        ]
        
        step("Given I capture an unnamed tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createAndCaptureTabGroup(named: false)
            tabGroupMenu.closeTabGroup(index: 0)
        }
        
        step("When I reopen all tabs") {
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
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
        testrailId("C1059")
        step("Given I capture an unnamed tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createAndCaptureTabGroup(named: false)
            tabGroupMenu.closeTabGroup(index: 0)
        }
        
        step("When I open one tab") {
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.getAutocompleteResults().element(boundBy: 1).clickInTheMiddle()
        }
        
        step("Then only the selected tab is opened") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), uiTestPageOne)
        }
    }
    
    func testNamedTabGroupInOmnibox() throws {
        testrailId("C1060")
        step("Given I capture a named tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createAndCaptureTabGroup(named: true)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("Then tab group name is displayed in omnibox") {
            omniboxView.searchInOmniBox("Test", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), tabGroupNamed)
        }
    }
    
    func testShareTabGroupNotLogged() throws {
        testrailId("C1171, C1163")
        let dialogView = DialogTestView()

        step("Given I capture an unnamed tab group") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
            createAndCaptureTabGroup(named: false)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("When I share tab group") {
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.shareTabGroup()
        }
        
        step("Then I get the connect alert message") {
            XCTAssertTrue(dialogView.isConnectTabGroupDisplayed())
        }
    }
    
    func testShareTabGroup() throws {
        try XCTSkipIf(true, "Skip while we have a stable public api for tab groups")
        testrailId("C1163")
        step("Given I capture an unnamed tab group") {
            setupStaging(withRandomAccount: true)
            webView.closeTab() // workaround for BE-5275
            uiMenu.createTabGroup()
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            tabGroupMenu.waitForTabGroupToBeDisplayed(index: 0)
            tabGroupMenu.captureTabGroup(index: 0)
        }
        
        step("When I share tab group") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.shareTabGroup()
        }
        
        step("Then tab group link is copied to pasteboard") {
            XCTAssertTrue(webView.staticText(TabGroupMenuViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            XCTAssertTrue(tabGroupMenu.isTabGroupLinkInPasteboard())
        }
    }
}
