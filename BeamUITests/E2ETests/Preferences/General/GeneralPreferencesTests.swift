//
//  GeneralPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 14.07.2022.
//

import Foundation
import XCTest

class GeneralPreferencesTests: BaseTest {
    
    let generalPrefView = GeneralPreferenceTestView()
    let basePrefView = PreferencesBaseView()
    let browserPrefView = BrowserPreferencesTestView()
    var journalView: JournalTestView!
    var startBeamCheckbox: XCUIElement!
    
    override func setUp() {
        journalView = launchApp()
        openGeneralPrefs()
        startBeamCheckbox = generalPrefView.getStartBeamWithOpenedTabsElement()
    }
    
    private func openGeneralPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        basePrefView.navigateTo(preferenceView: .general)
    }
    
    func testStartBeamWithOpenedTabs() {
        
        step("THEN I see Start beam with opened tabs checkbox available") {
            XCTAssertTrue(startBeamCheckbox.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.startBeamlabel.accessibilityIdentifier).exists)
        }
        
        step("WHEN Start beam with opened tabs and Restore all tabs from last session checkboxes are enabled") {
            if !startBeamCheckbox.isSettingEnabled() {
                startBeamCheckbox.tapInTheMiddle()
            }
            basePrefView.navigateTo(preferenceView: .browser)
            if !browserPrefView.getRestoreTabsCheckbox().isSettingEnabled() {
                browserPrefView.getRestoreTabsCheckbox().tapInTheMiddle()
            }
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("THEN Webview is opened on restart with openned tab") {
            uiMenu.loadUITestPage1()
            self.restartApp()
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
        }

        if !isBigSurOS() {
            step("THEN Webview is opened on restart with pinned tab") {
                webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
                self.restartApp()
                XCTAssertTrue(webView.waitForWebViewToLoad())
                XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            }
        }
        
        step("WHEN I disable Start beam with opened tabs checkbox") {
            openGeneralPrefs()
            startBeamCheckbox.clickOnExistence()
        }
        
        step("THEN Journal view is opened on restart") {
            self.restartApp()
            XCTAssertTrue(journalView
                            .waitForJournalViewToLoad()
                            .isJournalOpened())
        }
    }
    
    func testGeneralPrefsAppearanceElements() {
        
        step("THEN Appearance elements are correctly displayed") {
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.appearanceLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            for buttonID in GeneralPreferencesViewLocators.Buttons.allCases {
                XCTAssertTrue(generalPrefView.button(buttonID.accessibilityIdentifier).exists)
            }
        }
        
    }
    
    func testGeneralPrefsAccessibilityElements() {
        
        step("THEN Accessibility checkbox is correctly displayed") {
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.accessibilityLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(generalPrefView.checkBox(GeneralPreferencesViewLocators.Checkboxes.highlightTab.accessibilityIdentifier).exists)
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.highlightCheckboxDescription.accessibilityIdentifier).exists)
        }
    }
}
