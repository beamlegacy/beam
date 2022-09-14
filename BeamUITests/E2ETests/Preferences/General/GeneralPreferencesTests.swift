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
        journalView = launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
    }
    
    private func openGeneralPrefs() {
        shortcutHelper.shortcutActionInvoke(action: .openPreferences)
        basePrefView.navigateTo(preferenceView: .general)
    }
    
    func testStartBeamWithOpenedTabs() {
        testrailId("C586")
        
        step("THEN by default Journal view is opened on restart") {
            uiMenu.invoke(.loadUITestPage1)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            journalView.waitForJournalViewToLoad()
            self.restartApp(storeSessionWhenTerminated: true)
            XCTAssertTrue(journalView
                            .waitForJournalViewToLoad()
                            .isJournalOpened())
        }
        
        step("WHEN I enable Start beam with opened tabs checkbox") {
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            openGeneralPrefs()
            startBeamCheckbox = generalPrefView.getStartBeamWithOpenedTabsElement()
            XCTAssertTrue(startBeamCheckbox.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.startBeamlabel.accessibilityIdentifier).exists)
            startBeamCheckbox.clickOnExistence()
            shortcutHelper.shortcutActionInvoke(action: .close)
        }
        
        step("THEN Webview is opened on restart with opened tab") {
            self.restartApp(storeSessionWhenTerminated: true)
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
        }
        
        if !isBigSurOS() {
            step("THEN Webview is opened on restart with pinned tab") {
                webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
                self.restartApp(storeSessionWhenTerminated: true)
                XCTAssertTrue(webView.waitForWebViewToLoad())
                XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            }
        }
        
    }
    
    func testGeneralPrefsAppearanceElements() {
        testrailId("C585")
        step("THEN Appearance elements are correctly displayed") {
            openGeneralPrefs()
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.appearanceLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            for buttonID in GeneralPreferencesViewLocators.Buttons.allCases {
                XCTAssertTrue(generalPrefView.button(buttonID.accessibilityIdentifier).exists)
            }
        }
        
    }
    
    func testGeneralPrefsAccessibilityElements() {
        testrailId("C587")
        step("THEN Accessibility Press Tab to highlight checkbox is correctly displayed") {
            openGeneralPrefs()
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.accessibilityLabel.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(generalPrefView.checkBox(GeneralPreferencesViewLocators.Checkboxes.highlightTab.accessibilityIdentifier).exists)
            XCTAssertTrue(generalPrefView.staticText(GeneralPreferencesViewLocators.StaticTexts.highlightCheckboxDescription.accessibilityIdentifier).exists)
        }
        testrailId("C1106")
        step("THEN Accessibility Force click and haptic feedback checkbox is correctly displayed") {
            XCTAssertTrue(generalPrefView.checkBox(GeneralPreferencesViewLocators.Checkboxes.forceClickAndHapticFeedback.accessibilityIdentifier).exists)
        }
    }
}
