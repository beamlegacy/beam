//
//  TabGroupInOmniboxTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 16/08/2022.
//

import Foundation
import XCTest

class TabGroupInOmniboxTests: BaseTest {
    
    let tabGroupView = TabGroupView()
    let omniboxView = OmniBoxTestView()
    let dialogView = DialogTestView()
    let openAllTabsLabel = "Open All Tabs"
    let shareGroup = "Share Tab Group"
    let deleteGroup = "Delete Tab Group"
    let tabGroupUnnamedSuffix = " & 3 more"
    let tabGroupNamed = "Test1"

    private func createAndCaptureTabGroup (named: Bool){
        hiddenCommand.createTabGroupsCaptured(named: named)
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
            createAndCaptureTabGroup(named: false)
        }
        
        step("Then tab group is displayed in omnibox") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), uiTestPageOne + tabGroupUnnamedSuffix)
        }
        
        step("When I click on tab group") {
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnnamedSuffix)
        }
        
        step("Then tab group details are displayed") {
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count))
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnnamedSuffix)
            XCTAssertEqual(omniboxView.getAutocompleteResults().count, autocompleteResults.count)
            XCTAssertTrue(omniboxView.areAutocompleteResultsInCorrectOrder(results: autocompleteResults))
        }
        
        step("When I press Escape") {
            omniboxView.typeKeyboardKey(.escape)
        }
        
        step("Then omnibox is displayed with search autocomplete results") {
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), uiTestPageOne + tabGroupUnnamedSuffix)
        }
        
        step("When I press Enter") {
            omniboxView.typeKeyboardKey(.enter)
        }
        
        step("Then tab group details are displayed") {
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: autocompleteResults.count))
            XCTAssertEqual(omniboxView.getOmniBoxSearchField().placeholderValue, uiTestPageOne + tabGroupUnnamedSuffix)
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
            createAndCaptureTabGroup(named: false)
        }
        
        step("When I reopen all tabs") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.getAutocompleteResults().firstMatch.clickInTheMiddle()
        }
        
        step("Then all tabs are reopened in correct order") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(webView.areTabsInCorrectOrder(tabs: tabTitles))
        }
        
        step("And tab group name is correct") {
            XCTAssertEqual(tabGroupView.getTabGroupNameByIndex(index: 0), uiTestPageOne + tabGroupUnnamedSuffix)
        }
    }
    
    func testOpenIndividualTab() throws {
        testrailId("C1059")
        step("Given I capture an unnamed tab group") {
            createAndCaptureTabGroup(named: false)
        }
        
        step("When I open one tab") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnnamedSuffix)
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
            createAndCaptureTabGroup(named: true)
        }
        
        step("Then tab group name is displayed in omnibox") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Test", false)
            XCTAssertEqual(omniboxView.getAutocompleteResults().firstMatch.getStringValue(), tabGroupNamed)
        }
    }
    
    func testShareTabGroupNotLogged() throws {
        testrailId("C1171, C1163")

        step("Given I capture an unnamed tab group") {
            createAndCaptureTabGroup(named: false)
        }
        
        step("When I share tab group") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.shareTabGroup()
        }
        
        step("Then I get the connect alert message") {
            XCTAssertTrue(dialogView.isConnectTabGroupDisplayed())
        }
    }
    
    func testShareTabGroup() throws {
        testrailId("C1163")
        step("Given I capture an unnamed tab group") {
            signUpStagingWithRandomAccount()
            createAndCaptureTabGroup(named: false)
        }
        
        step("When I share tab group") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point", false)
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne + tabGroupUnnamedSuffix)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
            omniboxView.shareTabGroup()
        }
        
        step("Then tab group link is copied to pasteboard") {
            XCTAssertTrue(webView.staticText(TabGroupMenuViewLocators.StaticTexts.linkCopiedLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            XCTAssertTrue(tabGroupView.isTabGroupLinkInPasteboard())
        }
    }
    
    func testForgetTabGroup() throws {
        testrailId("C1173")
        step("Given I create an unnamed tab group") {
            createTabGroupAndSwitchToWeb(named: true)
        }
        
        step("When I open tab group in omnibox") {
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            omniboxView.selectAutocompleteResult(autocompleteResult: tabGroupNamed)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 7))
        }
        
        step("Then I have the option to forget the tab group") {
            XCTAssertTrue(omniboxView.isAutocompleteResultDisplayed(autocompleteResult: OmniboxLocators.Labels.forgetTabGroup.accessibilityIdentifier))
        }
        
        step("When I click to forget tab group") {
            omniboxView.forgetTabGroup()
        }
        
        step("Then confirmation pop up is displayed") {
            XCTAssertTrue(dialogView.isForgetTabGroupAlertDisplayed(tabGroupName: tabGroupNamed))
        }
        
        step("When I cancel to forget tab group") {
            dialogView.getButton(locator: .cancelButton).tapInTheMiddle()
        }
        
        step("Then tab group is not forgotten") {
            XCTAssertTrue(tabGroupView.isTabGroupDisplayed(index: 0))
        }
        
        step("When I forget tab group") {
            omniboxView.forgetTabGroup()
            dialogView.getButton(locator: .forgetButton).tapInTheMiddle()
        }
        
        step("Then tab group is forgotten") {
            XCTAssertFalse(tabGroupView.isTabGroupDisplayed(index: 0))
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(tabGroupNamed, false)
            XCTAssertFalse(omniboxView.isTabGroupResultDisplayed(tabGroupName: tabGroupNamed))
        }
    }
    
}
