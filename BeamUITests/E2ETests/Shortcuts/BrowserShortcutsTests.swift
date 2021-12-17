//
//  BrowserShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest

class BrowserShortcutsTests: BaseTest {
    
    let shortcutHelper = ShortcutsHelper()
    let wait = WaitHelper()
    let webView = WebTestView()
    let omniboxView = OmniBoxTestView()
    let testPage = UITestPagePasswordManager()
    
    func testWebTabsJumpOpenCloseReopen() {
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        testHelper.openTestPage(page: .password)
        testRailPrint("Given I open a web page")
        XCTAssertTrue(testPage.isPasswordPageOpened())

        testHelper.openTestPage(page: .password)
        testRailPrint("Given I open a second web page")
        XCTAssertTrue(testPage.isPasswordPageOpened())

        testRailPrint("Then I can open tabs using shortcuts")
        shortcutHelper.shortcutActionInvoke(action: .newTab)
        omniboxView.searchInOmniBox(testHelper.randomSearchTerm(), true)
        XCTAssertEqual(webView.getNumberOfTabs(), 3)
        XCTAssertFalse(testPage.isPasswordPageOpened())
        
        testRailPrint("Then I can close tabs using shortcuts")
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        testRailPrint("Then I can reopen tabs using shortcuts")
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 1)
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        XCTAssertTrue(testPage.isPasswordPageOpened())

        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: webView.getNumberOfTabs())
        XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
    }
    
    func testJumpBetweenWebTabs() throws {
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        testRailPrint("Given I open web pages")
        testHelper.openTestPage(page: .password)
        testHelper.openTestPage(page: .media)
        testHelper.openTestPage(page: .alerts)

        testRailPrint("Then I can jump between tabs using shortcuts")
                
        shortcutHelper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(self.isMediaPageOpened())
        
        shortcutHelper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        shortcutHelper.shortcutActionInvoke(action: .jumpToNextTab)
        XCTAssertTrue(self.isMediaPageOpened())
        
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .jumpToNextTab, numberOfTimes: 2)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        webView.dragDropTab(draggedTabIndexFromSelectedTab: 0, destinationTabIndexFromSelectedTab: 1)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        shortcutHelper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(self.isMediaPageOpened())

        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: webView.getNumberOfTabs())
        XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
    }
    
    func testWebPageReload() {
        let journalView = launchApp()
        testRailPrint("Given I open a web page")
        BeamUITestsHelper(journalView.app).openTestPage(page: .password)
        
        testRailPrint("Then I can reload webpage using shortcuts")
        XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        testPage.enterInput("xyz", .username)
        XCTAssertNotEqual(testPage.getInputValue(.username), emptyString)
        shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        XCTAssertEqual(testPage.getInputValue(.username), emptyString)

        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: webView.getNumberOfTabs())
        XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
    }
    
    func testReopenTabsCmdT() throws {
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        let expectedTabsNumber = 3
        
        testRailPrint("Then nothing happens by default on CMD+T action")
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 5)
        let numberOfTabs = webView.getNumberOfTabs(wait: false)
        if numberOfTabs > 0 {
            // close any left overs from other tests
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: numberOfTabs)
        }
        XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)

        testRailPrint("Given I open web pages")
        testHelper.openTestPage(page: .password)
        testHelper.openTestPage(page: .media)
        testHelper.openTestPage(page: .alerts)
        
        testRailPrint("When I quit the app")
        restartApp()
        
        testRailPrint("Then tabs are reopened on app relaunch")
        journalView.waitForJournalViewToLoad()
        shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        
        testRailPrint("Then no other tabs are reopened on additional CMD+T action")
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 5)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        
        testRailPrint("When I close tabs")
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
        
        testRailPrint("Then no other tabs are reopened on one per CMD+T action")
        shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: webView.getTabs()))
        shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 3, elementQuery: webView.getTabs()))

        //Clean tabs since restoreLastBeamSessionDefault is ON by default
        shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: webView.getNumberOfTabs())
        XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
    }
    
    func isMediaPageOpened() -> Bool {
        return webView.button("Play Audio").waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isAlertsPageOpened() -> Bool {
        return webView.button("Trigger an alert").waitForExistence(timeout: minimumWaitTimeout)
    }
}
