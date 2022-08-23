//
//  BrowserShortcutsTests.swift
//  BeamUITests
//
//  Created by Andrii on 11/10/2021.
//

import Foundation
import XCTest

class BrowserShortcutsTests: BaseTest {
    
    let omniboxView = OmniBoxTestView()
    let testPage = UITestPagePasswordManager()
    var journalView: JournalTestView!
    
    override func setUp() {
        journalView = launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
    }
    
    func testWebTabsJumpOpenCloseReopen() {
        step ("Given I open a web page"){
            uiMenu.loadUITestPagePassword()
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }
        
        step ("Given I open a second web page"){
            uiMenu.loadUITestPageAlerts()
            XCTAssertTrue(testPage.isAlertPageOpened())
        }

        testrailId("C501")
        step ("Then I can open tabs using shortcuts"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            omniboxView.searchInOmniBox(self.getRandomSearchTerm(), true)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 3)
            XCTAssertFalse(testPage.isPasswordPageOpened())
            XCTAssertFalse(testPage.isAlertPageOpened())
        }
        
        testrailId("C507")
        step ("Then I can close tabs using shortcuts"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .closeTab, numberOfTimes: 2)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertTrue(testPage.isPasswordPageOpened())
            XCTAssertFalse(testPage.isAlertPageOpened())
        }
        
        testrailId("C502")
        step ("Then I can reopen tabs using shortcuts"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertTrue(testPage.isAlertPageOpened())
            XCTAssertFalse(testPage.isPasswordPageOpened())
        }

    }
    
    func testJumpBetweenWebTabs() throws {
 
        step ("Given I open web pages"){
            uiMenu.loadUITestPagePassword()
                .loadUITestPageMedia()
                .loadUITestPageAlerts()
        }
        
        step ("Then I can jump between tabs using shortcuts"){
            testrailId("C1145, C1146")
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
            uiMenu.loadUITestPagePassword()
        }
        
        testrailId("C556")
        step ("Then I can reload webpage using shortcuts"){
            XCTAssertEqual(testPage.getInputValue(.username), emptyString)
            testPage.enterInput("xyz", .username)
            XCTAssertNotEqual(testPage.getInputValue(.username), emptyString)
            shortcutHelper.shortcutActionInvoke(action: .reloadPage)
            _ = webView.waitForWebViewToLoad()
            XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        }
        
    }
    
    func testReopenTabsCmdT() {
        let expectedTabsNumber = 3
        
        step ("Then nothing happens by default on CMD+T action"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .reOpenClosedTab, numberOfTimes: 5)
            XCTAssertEqual(webView.getNumberOfTabs(wait: false), 0)
        }
        
        step ("Given I open web pages"){
            uiMenu.loadUITestPagePassword()
                .loadUITestPageMedia()
                .loadUITestPageAlerts()
        }
        
        step ("When I quit the app"){
            restartApp(storeSessionWhenTerminated: false)
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
    
    func testTextInstantSearchInNewTabShortcut () {
        
        let textToSelect = "H-beam"
        let expectedSearchTextPart1 = "beam - "
        let expectedSearchTextPart2 = "Google"
        
        step("GIVEN I open test page") {
            uiMenu.loadUITestPage2()
        }
        
        step("WHEN I select \(textToSelect) and press CMD+Return") {
            webView.app.staticTexts[textToSelect].firstMatch.doubleTapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .instantSearch)
        }
        
        step("THEN new tab is opened and it has search text of  \(expectedSearchTextPart1) and \(expectedSearchTextPart2)") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertTrue(webView.waitForTabTitleToContain(index: 1, expectedString: expectedSearchTextPart1))
            XCTAssertTrue(webView.waitForTabTitleToContain(index: 1, expectedString: expectedSearchTextPart2))
        }
    }
    
    func isMediaPageOpened() -> Bool {
        webView.button("Play Audio").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isAlertsPageOpened() -> Bool {
        webView.button("Trigger an alert").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
}
