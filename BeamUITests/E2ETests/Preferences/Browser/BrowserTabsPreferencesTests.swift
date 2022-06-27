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
    var journalView: JournalTestView!
    
    override func setUpWithError() throws {
        step ("GIVEN I open Browser preferences"){
            launchApp()
            openBrowserPrefs()
            browserPref.waitForViewToLoad()
        }
    }
    
    private func openBrowserPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(preferenceView: .browser)
    }
        
    func testCMDClickFunctionalityEnablingDisabling() {
        
        let expectedCheckboxTitle = "⌘-click opens a link in a new tab"
        
        step("THEN by default checkbox is enabled by default and has title: \(expectedCheckboxTitle)") {
            XCTAssertEqual(browserPref.getCMDClickCheckbox().title, expectedCheckboxTitle)
            XCTAssertTrue(browserPref.getCMDClickCheckbox().isSettingEnabled())
        }
        
        //Checkbox disabling check is blocked by https://linear.app/beamapp/issue/BE-4535/optiontab-highlighting-is-skips-some-elements-on-web-pages
    }
    
    func testRestoreAllTabsFromLastSession() {
        
        let expectedCheckboxTitle = "Restore all tabs from last session"
        
        step("WHEN I prepare checkbox that has title: \(expectedCheckboxTitle)") {
            XCTAssertEqual(browserPref.getRestoreTabsCheckbox().title, expectedCheckboxTitle)
            if browserPref.getRestoreTabsCheckbox().isSettingEnabled() {
                browserPref.getRestoreTabsCheckbox().tapInTheMiddle()
            }
            browserPref.getRestoreTabsCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("WHEN I open multiple tabs") {
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            webView.waitForWebViewToLoad()
        }
        
        step("WHEN I restart the app") {
            journalView = restartApp()
        }
        
        step("THEN I'm on the web view with 2 tabs reopened") {
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }
        
        step("WHEN I disable Restore tabs checkbox") {
            openBrowserPrefs()
            browserPref.waitForViewToLoad()
            browserPref.getRestoreTabsCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("WHEN I restart the app") {
            journalView = restartApp()
        }
        
        step("THEN I'm on the Journal view") {
            XCTAssertTrue(journalView
                            .waitForJournalViewToLoad()
                            .isJournalOpened())
        }
        
    }
    
    func testSwitchTabsUsingCMDNumber() {
        
        let expectedCheckboxTitle = "Use ⌘1 to ⌘9 to switch tabs"
        
        step("WHEN enable Switch Tabs checkbox that has title: \(expectedCheckboxTitle)") {
            XCTAssertEqual(browserPref.getSwitchTabsCheckbox().title, expectedCheckboxTitle)
            if !browserPref.getSwitchTabsCheckbox().isSettingEnabled() {
                browserPref.getSwitchTabsCheckbox().tapInTheMiddle()
            }
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSetDefaultButton())
        }
        
        step("WHEN I open multiple tabs") {
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            uiMenu.loadUITestPage3()
            uiMenu.loadUITestPage4()
            webView.waitForWebViewToLoad()
            webView.getTabByIndex(index: 1).tapInTheMiddle()
        }
        
        step("THEN I CAN successfully switch the tabs using shortcuts") {
            shortcutHelper.invokeCMDKey("1")
            XCTAssertTrue(waitFor(PredicateFormat.isSelected.rawValue, webView.getTabByIndex(index: 0), BaseTest.implicitWaitTimeout))
            webView.getTabByIndex(index: 3).tapInTheMiddle()
            shortcutHelper.invokeCMDKey("3")
            XCTAssertTrue(waitFor(PredicateFormat.isSelected.rawValue, webView.getTabByIndex(index: 2), BaseTest.implicitWaitTimeout))
        }
        
        step("WHEN I disable Switch tabs checkbox") {
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            browserPref.waitForViewToLoad()
            browserPref.getSwitchTabsCheckbox().tapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .close)
            waitForDoesntExist(browserPref.getSetDefaultButton())
        }
        
        step("THEN I can NOT switch the tabs using shortcuts") {
            XCTAssertTrue(webView.waitForWebViewToLoad())
            webView.getTabByIndex(index: 0).tapInTheMiddle()
            shortcutHelper.invokeCMDKey("2")
            XCTAssertFalse(waitFor(PredicateFormat.isSelected.rawValue, webView.getTabByIndex(index: 3), BaseTest.minimumWaitTimeout))
            shortcutHelper.invokeCMDKey("4")
            XCTAssertFalse(waitFor(PredicateFormat.isSelected.rawValue, webView.getTabByIndex(index: 3), BaseTest.minimumWaitTimeout))
        }
    }
}
