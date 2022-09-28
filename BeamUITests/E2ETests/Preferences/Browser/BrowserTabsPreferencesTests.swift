//
//  BrowserTabsPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 23.06.2022.
//

import Foundation
import XCTest

class BrowserTabsPreferencesTests: BaseTest {
    
    let browserPref = BrowserPreferencesTestView()
    let omnibox = OmniBoxTestView()
    
    private func openBrowserPrefs() {
        step ("GIVEN I open Browser preferences"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .browser)
            browserPref.waitForViewToLoad()
        }
    }
        
    func testCMDClickFunctionalityEnablingDisabling() {
        testrailId("C594")
        let expectedCheckboxTitle = "⌘-click opens a link in a new tab"
        openBrowserPrefs()
        step("THEN by default checkbox is enabled and has title: \(expectedCheckboxTitle)") {
            XCTAssertEqual(browserPref.getCMDClickCheckbox().title, expectedCheckboxTitle)
            XCTAssertTrue(browserPref.getCMDClickCheckbox().isSettingEnabled())
        }
        
        //Checkbox disabling check is blocked by https://linear.app/beamapp/issue/BE-4535/optiontab-highlighting-is-skips-some-elements-on-web-pages
    }
    
    func testSwitchTabsUsingCMDNumber() {
        testrailId("C595")
        let expectedCheckboxTitle = "Use ⌘1 to ⌘9 to switch tabs"
        
        step("WHEN I open multiple tabs") {
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage2)
                .invoke(.loadUITestPage3)
                .invoke(.loadUITestPage4)
            webView.waitForWebViewToLoad()
            webView.getTabByIndex(index: 1).tapInTheMiddle()
        }
        
        step("THEN I can NOT switch the tabs using shortcuts by default") {
            XCTAssertTrue(webView.waitForWebViewToLoad())
            webView.getTabByIndex(index: 0).tapInTheMiddle()
            shortcutHelper.invokeCMDKey("2")
            XCTAssertTrue(webView.getTabByIndex(index: 0).isSelected)
            XCTAssertFalse(webView.getTabByIndex(index: 3).isSelected)
            shortcutHelper.invokeCMDKey("4")
            XCTAssertTrue(webView.getTabByIndex(index: 0).isSelected)
            XCTAssertFalse(webView.getTabByIndex(index: 3).isSelected)
        }
        
        step("WHEN enable Switch Tabs checkbox that has title: \(expectedCheckboxTitle)") {
            openBrowserPrefs()
            XCTAssertEqual(browserPref.getSwitchTabsCheckbox().title, expectedCheckboxTitle)
            browserPref.getSwitchTabsCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSetDefaultButton())
        }
        
        step("THEN I CAN successfully switch the tabs using shortcuts") {
            shortcutHelper.invokeCMDKey("1")
            XCTAssertTrue(webView.getTabByIndex(index: 0).isSelected)
            webView.getTabByIndex(index: 3).tapInTheMiddle()
            shortcutHelper.invokeCMDKey("3")
            XCTAssertTrue(webView.getTabByIndex(index: 2).isSelected)
        }
    }
    
    func testGroupTabsAutomatically() {
        testrailId("C593")
        let expectedCheckboxTitle = "Group tabs automatically"
        let tabGroupView = TabGroupView()
        
        step("WHEN I open multiple time the same tab") {
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage1)
            webView.waitForWebViewToLoad()
        }
        
        step("THEN tab group is automatically created by default") {
            XCTAssertTrue(tabGroupView.isTabGroupDisplayed(index: 0))
            // Closing opened tabs
            shortcutHelper.shortcutActionInvoke(action: .close)
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
    
        step("WHEN I disable Auto Group Tab checkbox that has title: \(expectedCheckboxTitle)") {
            openBrowserPrefs()
            browserPref.waitForViewToLoad()
            browserPref.getAutoGroupTabsCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
            shortcutHelper.shortcutActionInvoke(action: .newWindow)
        }
        
        step("WHEN I open multiple time the same tab") {
            uiMenu.invoke(.loadUITestPage2)
                .invoke(.loadUITestPage2)
            webView.waitForWebViewToLoad()
        }

        step("THEN tab group is automatically created") {
            XCTAssertFalse(tabGroupView.isTabGroupDisplayed(index: 0))
        }
    }
}
