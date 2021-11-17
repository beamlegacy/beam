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
    
    func testReopenTabsAfterQuit() throws {
        try XCTSkipIf(true, "blocked by https://linear.app/beamapp/issue/BE-2257/cmdshiftt-undo-stack-is-not-saved-if-the-app-crashes-which-means-i")
        let journalView = launchApp()
        let testHelper = BeamUITestsHelper(journalView.app)
        let expectedTabsNumber = 3
        testRailPrint("Given I open web pages")
        testHelper.openTestPage(page: .password)
        testHelper.openTestPage(page: .media)
        testHelper.openTestPage(page: .alerts)
        XCTAssertEqual(webView.getNumberOfTabs(), expectedTabsNumber, "")
        
        testRailPrint("When I quit the app")
        helper.shortcutActionInvoke(action: .quitApp)
        XCTAssertTrue(self.waitUntiAppIsNotRunning(), "co.beamapp.macos still running after app quit action")
        launchApp()
        testRailPrint("Then tabs are reopened on app relaunch")
        helper.shortcutActionInvoke(action: .reopenClosedTab)
        XCTAssertTrue(WaitHelper().waitForCountValueEqual(timeout: minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
    }
    
    func isMediaPageOpened() -> Bool {
        return webView.button("Play Audio").waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isAlertsPageOpened() -> Bool {
        return webView.button("Trigger an alert").waitForExistence(timeout: minimumWaitTimeout)
    }
}
