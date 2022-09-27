//
//  AppLifecycleTests.swift
//  BeamUITests
//
//  Created by Thomas on 07.11.2022.
//

import Foundation
import XCTest

class AppLifecycleTests: BaseTest {

    let windowMenu = WindowMenu()
    var journalView: JournalTestView!

    override func setUp(){
        launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
    }
    
    func testOpenNewWindowCloseItAndQuitApp() {
        testrailId("C499")
        step("THEN I open new window successfully") {
            shortcutHelper.shortcutActionInvoke(action: .newWindow)
            XCTAssertEqual(getNumberOfWindows(), 2)
        }
        
        testrailId("C506")
        step("THEN I close window successfully") {
            shortcutHelper.shortcutActionInvoke(action: .closeWindow)
            XCTAssertEqual(getNumberOfWindows(), 1)
        }
        
        step("THEN app is still running on closing last window") {
            shortcutHelper.shortcutActionInvoke(action: .closeWindow)
            XCTAssertEqual(getNumberOfWindows(), 0)
            XCTAssertTrue(isAppRunning())
        }
        
        testrailId("C498")
        step("THEN I quit app successfully") {
            shortcutHelper.shortcutActionInvoke(action: .quitApp)
            // let 5 seconds to the app to quit
            let background = app.wait(for: .notRunning, timeout: 5)
            XCTAssertTrue(background)
        }
    }
    
    func testRestoreAllTabsFromLastSession() {
        testrailId("C906")

        step("WHEN I open multiple tabs and one incognito window") {
            uiMenu.invoke(.loadUITestPage1)
                .invoke(.loadUITestPage2)
            webView.waitForWebViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .newIncognitoWindow)
        }

        step("WHEN I restart the app") {
            journalView = restartApp(storeSessionWhenTerminated: false)
        }

        step("THEN I'm on the web view with 2 tabs reopened and the incognito window is not restored") {
            XCTAssertEqual(getNumberOfWindows(), 1)
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }

        step("WHEN I restart the app") {
            journalView = restartApp(storeSessionWhenTerminated: false)
        }

        step("THEN I'm on the Journal view") {
            XCTAssertTrue(journalView
                            .waitForJournalViewToLoad()
                            .isJournalOpened())
        }

        step("THEN I restore the last session manually via the menu item") {
            windowMenu.reopenAllWindowsFromLastSession()
        }

        step("THEN I'm on the web view with 2 tabs reopened") {
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }

        step("THEN I close the windows in the right order") {
            XCTAssertEqual(getNumberOfWindows(), 2)
            _ = windowMenu.windowMenu().menuItem("Beam").firstMatch.hoverAndTapInTheMiddle()
            shortcutHelper.shortcutActionInvoke(action: .closeWindow)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 1, elementQuery: getWindowsQuery()))
            shortcutHelper.shortcutActionInvoke(action: .closeWindow)
            XCTAssertTrue(waitForCountValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 0, elementQuery: getWindowsQuery()))
        }

        step("THEN I restore the last session manually via the menu item") {
            windowMenu.reopenAllWindowsFromLastSession()
        }

        step("THEN I have one window in web mode with 2 tabs reopened") {
            XCTAssertTrue(webView.waitForWebViewToLoad())
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }
    }
}
