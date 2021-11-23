//
//  BrowserShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest

class BrowserShortcutsTests: BaseTest {
    
    let helper = ShortcutsHelper()
    let wait = WaitHelper()
    let webView = WebTestView()
    let testPage = UITestPagePasswordManager()
    
    func testWebTabsJumpOpenCloseReopen() {
        let journalView = launchApp()
        BeamUITestsHelper(journalView.app).openTestPage(page: .password)
        testRailPrint("Given I open a web page")
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        testRailPrint("Then I can open tabs using shortcuts")
        helper.shortcutActionInvokeRepeatedly(action: .newTab, numberOfTimes: 9)
        XCTAssertEqual(webView.getNumberOfTabs(), 10)
        XCTAssertFalse(testPage.isPasswordPageOpened())
        
        testRailPrint("Then I can close tabs using shortcuts")
        helper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 9)
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        testRailPrint("Then I can reopen tabs using shortcuts")
        helper.shortcutActionInvokeRepeatedly(action: .reopenClosedTab, numberOfTimes: 5)
        XCTAssertEqual(webView.getNumberOfTabs(), 6)
        XCTAssertFalse(testPage.isPasswordPageOpened())
    }
    
    func testJumpBetweenWebTabs() throws {
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        testRailPrint("Given I open web pages")
        testHelper.openTestPage(page: .password)
        testHelper.openTestPage(page: .media)
        testHelper.openTestPage(page: .alerts)
        helper.shortcutActionInvoke(action: .newTab)

        testRailPrint("Then I can jump between tabs using shortcuts")
        helper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(self.isAlertsPageOpened())
                
        helper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(self.isMediaPageOpened())
        
        helper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        helper.shortcutActionInvoke(action: .jumpToNextTab)
        XCTAssertTrue(self.isMediaPageOpened())
        
        helper.shortcutActionInvokeRepeatedly(action: .jumpToNextTab, numberOfTimes: 3)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        webView.dragDropTab(draggedTabIndexFromSelectedTab: 0, destinationTabIndexFromSelectedTab: 1)
        XCTAssertTrue(testPage.isPasswordPageOpened())
        
        helper.shortcutActionInvoke(action: .jumpToPreviousTab)
        XCTAssertTrue(self.isMediaPageOpened())
    }
    
    func testWebPageReload() {
        let journalView = launchApp()
        testRailPrint("Given I open a web page")
        BeamUITestsHelper(journalView.app).openTestPage(page: .password)
        
        testRailPrint("Then I can reload webpage using shortcuts")
        XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        testPage.enterInput("xyz", .username)
        XCTAssertNotEqual(testPage.getInputValue(.username), emptyString)
        helper.shortcutActionInvoke(action: .reloadPage)
        XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        
        testRailPrint("Then I can jump between tabs using reload button")
        testPage.enterInput("abc", .password)
        XCTAssertNotEqual(testPage.getInputValue(.password), emptyString)
        OmniBarTestView().clickRefreshButton()
        XCTAssertEqual(testPage.getInputValue(.password), emptyString)
    }
    
    func testReopenTabsCmdT() throws {
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        let expectedTabsNumber = 3
        
        testRailPrint("Then nothing happens by default on CMD+T action")
        helper.shortcutActionInvokeRepeatedly(action: .reopenClosedTab, numberOfTimes: 5)
        
        testRailPrint("Given I open web pages")
        testHelper.openTestPage(page: .password)
        testHelper.openTestPage(page: .media)
        helper.shortcutActionInvoke(action: .newTab)
        testHelper.openTestPage(page: .alerts)
        
        testRailPrint("When I quit the app")
        restartApp()
        
        testRailPrint("Then tabs are reopened on app relaunch")
        journalView.waitForJournalViewToLoad()
        helper.shortcutActionInvoke(action: .reopenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        
        testRailPrint("Then no other tabs are reopened on additional CMD+T action")
        helper.shortcutActionInvokeRepeatedly(action: .reopenClosedTab, numberOfTimes: 5)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        
        testRailPrint("When I close tabs")
        helper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
        
        testRailPrint("Then no other tabs are reopened on one per CMD+T action")
        helper.shortcutActionInvoke(action: .reopenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 2, elementQuery: webView.getTabs()))
        helper.shortcutActionInvoke(action: .reopenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: 3, elementQuery: webView.getTabs()))
    }
    
    func isMediaPageOpened() -> Bool {
        return webView.button("Play Audio").waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isAlertsPageOpened() -> Bool {
        return webView.button("Trigger an alert").waitForExistence(timeout: minimumWaitTimeout)
    }
}
