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

    func testRestoreAllTabsFromLastSession() {
        testrailId("C906")
        step("WHEN I prepare app") {
            launchApp(storeSessionWhenTerminated: true, preventSessionRestore: true)
        }

        step("WHEN I open multiple tabs and one incognito window") {
            uiMenu.loadUITestPage1()
            uiMenu.loadUITestPage2()
            webView.waitForWebViewToLoad()
            shortcutHelper.shortcutActionInvoke(action: .newIncognitoWindow)
        }

        step("WHEN I restart the app") {
            journalView = restartApp(storeSessionWhenTerminated: false)
        }

        step("THEN I'm on the web view with 2 tabs reopened and the incognito window is not restored") {
            XCTAssertTrue(app.windows.count == 1)
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
    }
}
