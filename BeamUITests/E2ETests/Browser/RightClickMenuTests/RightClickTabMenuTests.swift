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
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage2)
                .invoke(.loadUITestPage3)
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
            uiMenu.invoke(.loadUITestPage1)
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
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage2)
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
            uiMenu.invoke(.loadUITestPagePassword)
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
    
    func testMoveTabToSideWindowAndCloseConferenceDialog() throws {
        try XCTSkipIf(isBigSurOS(), "not running on BigSur for meet behavior")
        testrailId("C1187")
        let meetingId = "rox-yfpc-yqi"
        var conferenceDialog: XCUIElement!
        
        step("GIVEN I open normal tab and tab with \(meetingId) conference meeting"){
            uiMenu.invoke(.loadUITestPage1)
            webView.waitForWebViewToLoad()
            OmniBoxTestView().openWebsite("meet.google.com/\(meetingId)")
            conferenceDialog = app.dialogs.firstMatch
            let conferenceDialogPermissionDontAllowButton = app.sheets.buttons[AlertViewLocators.Buttons.dontAllowButton.accessibilityIdentifier]
            
            if conferenceDialogPermissionDontAllowButton.waitForExistence(timeout: BaseTest.implicitWaitTimeout) {
                conferenceDialogPermissionDontAllowButton.hoverAndTapInTheMiddle()
                XCTAssertTrue(waitForDoesntExist(conferenceDialog.sheets.firstMatch))
            }
        }
        
        // TODO with preferences of tab window
//        step("WHEN I move \(meetingId) tab to a conference window"){
//            webView
//                .openTabMenu(tabIndex: 0)
//                .selectTabMenuItem(.moveTabToSideWindow)
//        }
        
         
        step("THEN I web meeting tab is moved to video conference window") {
            XCTAssertEqual(getNumberOfWindows(), 1)
            XCTAssertTrue(conferenceDialog.waitForExistence(timeout: BaseTest.maximumWaitTimeout))
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            // Comment out due to flakiness when based on meeting state when the user cannot join the meeting the icons are not displayed - https://linear.app/beamapp/issue/BE-5646/ui-menu-to-invoke-mocked-conference-window
            /*for identifier in ConferencePopupViewLocators.Buttons.allCases {
                XCTAssertTrue(conferenceDialog.buttons[identifier.accessibilityIdentifier].exists)
            }*/
        }
        
        step("THEN only web conferences meetings has the option to be moved in a conference window") {
            XCTAssertFalse(webView.openTabMenu(tabIndex: 0).isTabMenuOptionDisplayed(.moveTabToSideWindow))
            webView.typeKeyboardKey(.escape)
        }
        
        step("THEN I successfully move conference window back to tab"){
            conferenceDialog.hoverAndTapInTheMiddle() //required to activate the dialog
            conferenceDialog.buttons[ConferencePopupViewLocators.Buttons.openInMainWindowButton.accessibilityIdentifier].hoverAndTapInTheMiddle()
            XCTAssertTrue(waitForDoesntExist(conferenceDialog))
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }
        
        step("THEN I can move \(meetingId) tab back to a conference window again"){
            webView
                .openTabMenu(tabIndex: 1)
                .selectTabMenuItem(.moveTabToSideWindow)
            XCTAssertTrue(conferenceDialog.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        
        step("THEN I successfully close the conference window"){
            conferenceDialog.buttons[ConferencePopupViewLocators.Buttons.closeButton.accessibilityIdentifier].hoverAndTapInTheMiddle()
            XCTAssertTrue(waitForDoesntExist(conferenceDialog))
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
        }
        
        
    }
}
