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
    let webView = WebTestView()
    let omniboxView = OmniBoxTestView()
    let testPage = UITestPagePasswordManager()
    let uiMenuBar = UITestsMenuBar()
    var journalView = JournalTestView()
    var testHelper = BeamUITestsHelper(JournalTestView().app)
    
    override func setUpWithError() throws{
        try super.setUpWithError()
        journalView = launchApp()
        uiMenuBar.destroyDB()
        testHelper = BeamUITestsHelper(journalView.app)
    }
    
    func testWebTabsJumpOpenCloseReopen() {
        step ("Given I open a web page"){
            testHelper.openTestPage(page: .password)
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }
        
        step ("Given I open a second web page"){
            testHelper.openTestPage(page: .password)
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }

        step ("Then I can open tabs using shortcuts"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            omniboxView.searchInOmniBox(testHelper.randomSearchTerm(), true)
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
            XCTAssertFalse(testPage.isPasswordPageOpened())
        }
        
        step ("Then I can close tabs using shortcuts"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }
        
        step ("Then I can reopen tabs using shortcuts"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 1)
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }

    }
    
    func testJumpBetweenWebTabs() throws {
        step ("Given I open web pages"){
            testHelper.openTestPage(page: .password)
            testHelper.openTestPage(page: .media)
            testHelper.openTestPage(page: .alerts)
        }
    
        step ("Then I can jump between tabs using shortcuts"){
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

        }
        
    }
    
    func testWebPageReload() {
        step ("Given I open a web page"){
            testHelper.openTestPage(page: .password)
        }
        
        step ("Then I can reload webpage using shortcuts"){
            XCTAssertEqual(testPage.getInputValue(.username), emptyString)
            testPage.enterInput("xyz", .username)
            XCTAssertNotEqual(testPage.getInputValue(.username), emptyString)
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
            XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        }
        
    }
    
    func testReopenTabsCmdT() throws {
        let expectedTabsNumber = 3
        
        step ("Then nothing happens by default on CMD+T action"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 5)
            XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
        }
        
        step ("Given I open web pages"){
            testHelper.openTestPage(page: .password)
            testHelper.openTestPage(page: .media)
            testHelper.openTestPage(page: .alerts)
        }
        
        step ("When I quit the app"){
            restartApp()
        }
    
        step ("Then tabs are reopened on app relaunch"){
            journalView.waitForJournalViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        }
        
        step ("Then no other tabs are reopened on additional CMD+T action"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 5)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: expectedTabsNumber, elementQuery: webView.getTabs()))
        }
        
        step ("When I close tabs"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 1, elementQuery: webView.getTabs()))
        }
        
        step ("Then no other tabs are reopened on one per CMD+T action"){
            shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 2, elementQuery: webView.getTabs()))
            shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 3, elementQuery: webView.getTabs()))
        }
    }
    
    func isMediaPageOpened() -> Bool {
        webView.button("Play Audio").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isAlertsPageOpened() -> Bool {
        webView.button("Trigger an alert").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
}
