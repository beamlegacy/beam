//
//  RightClickTabMenuTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.08.2022.
//

import Foundation
import XCTest

class RightClickTabMenuTests: BaseTest {
    
    private func openThreeTabsAndSwitchToWebView() {
        
        step("GIVEN I open 3 web pages in 3 tabs"){
            launchApp().waitForJournalViewToLoad()
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            uiMenu.loadUITestPage3()
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
        }
    }
    
    func testCloseTabsToTheRight() {
        testrailId("C1068")
        openThreeTabsAndSwitchToWebView()
        
        step("THEN Close Tabs to the right is disabled for the last tab"){
            XCTAssertFalse(webView.openTabMenu(tabIndex: 2).isTabMenuOptionEnabled(.closeTabsToTheRight))
        }
        
        step("WHEN I Close Tabs to the right on 2nd tab"){
            webView.openTabMenu(tabIndex: 1).selectTabMenuItem(.closeTabsToTheRight)
        }
        
        step("THEN only 3rd tab is closed") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
        }
        
        step("THEN Close Tabs to the right is disabled for the last tab") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 1).isTabMenuOptionEnabled(.closeTabsToTheRight))
        }
    }
    
    func testCloseOtherTabs() {
        testrailId("C1069")
        openThreeTabsAndSwitchToWebView()
        
        step("WHEN I Close Other Tabs on 2nd tab"){
            webView.openTabMenu(tabIndex: 1).selectTabMenuItem(.closeOtherTabs)
        }
        
        step("THEN all other tabs are closed") {
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
        }
        
        step("THEN Close Other Tabs is disabled for remained tab") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 0).isTabMenuOptionEnabled(.closeOtherTabs))
        }
    }
    
    func testMuteTab() {
        testrailId("C1070")
        step("GIVEN I open a web page where no sounds are playing"){
            launchApp().waitForJournalViewToLoad()
            uiMenu.loadUITestPage1()
            XCTAssertTrue(webView.waitForWebViewToLoad())
        }
        
        step("THEN I see Mute tab option is disabled") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 0).isTabMenuOptionEnabled(.muteTab))
        }
        
        //assertion to make sure mute tab is enabled is blocked by https://linear.app/beamapp/issue/BE-5056/tab-with-sound-playing-is-not-recognized-as-it-plays-any-sound
        
    }
    
    func testCopyAddressPasteAndGo() {
        testrailId("C1071, C1072")
        step("GIVEN I open 2 different web pages"){
            launchApp().waitForJournalViewToLoad()
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            XCTAssertTrue(webView.waitForWebViewToLoad())
        }
        
        step("WHEN I copy address of the first tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.copyAddress)
        }
        
        step("WHEN I paste and go copied URL"){
            webView.openTabMenu(tabIndex: 1).selectTabMenuItem(.pasteAndGo)
        }
        
        step("THEN refreshed tab 2 is the same as tab 1"){
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 0), webView.getBrowserTabTitleValueByIndex(index: 1))
        }
    }
    
    func testRefreshTab() {
        testrailId("C1073")
        
        let testPage = UITestPagePasswordManager()
        let fakeData = "Fake Data"
        step("GIVEN I open a web page"){
            launchApp().waitForJournalViewToLoad()
            uiMenu.loadUITestPagePassword()
            XCTAssertTrue(testPage.isPasswordPageOpened())
        }

        step("WHEN I enter data in page"){
            testPage.clickInputField(.username).typeSlowly(fakeData, everyNChar: 2)
        }

        step("AND I refresh tab"){
            XCTAssertEqual(testPage.getInputValue(.username), fakeData)
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.refreshTab)
            XCTAssertTrue(webView.waitForWebViewToLoad())
        }
        
        step("THEN tab is correctly refreshed"){
            XCTAssertEqual(webView.getNumberOfTabs(), 1) // no new tab created
            XCTAssertTrue(testPage.isPasswordPageOpened())
            XCTAssertEqual(testPage.getInputValue(.username), emptyString)
        }
    }
}
