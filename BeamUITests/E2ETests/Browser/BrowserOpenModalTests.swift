//
//  BrowserOpenModalTests.swift
//  BeamUITests
//
//  Created by Stef Kors on 04/04/2022.
//

import XCTest

class BrowserOpenModalTests: BaseTest {

    let testPage = UITestPageBrowserWindow()

    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
    }

    func testOpenModalInNewWindowTHENNewTab() {
        step("WHEN the page has opened"){
            mockPage.openMockPage(.newWindowBrowser)
        }

        step("Given I tap on the open window button") {
            testPage.tapOpenWindow()
        }

        step("THEN I see two windows"){
            // wait for window to open
            waitForIntValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getNumberOfWindows())
            XCTAssertEqual(getNumberOfWindows(), 2)
        }

        step("Given I tap on the open tab button in the new window") {
            testPage.tapOpenTab()
        }

        step("THEN I see two tabs AND I see two windows"){
            // assert the minimal webview has no tabs
            // main window has 2 tabs
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(getNumberOfWindows(), 2)
        }
    }

    func testOpenModalInNewWindowTHENNewTab_Async() {
        step("WHEN the page has opened"){
            mockPage.openMockPage(.newWindowBrowser)
        }

        step("Given I tap on the open window button") {
            testPage.tapOpenWindow()
        }

        step("THEN I see two windows"){
            // wait for window to open
            waitForIntValueEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getNumberOfWindows())
            XCTAssertEqual(getNumberOfWindows(), 2)
        }

        step("Given I tap on the open tab button in the new window") {
            testPage.tapOpenTab()
        }

        step("THEN I see two tabs AND I see two windows"){
            // assert the minimal webview has no tabs
            // main window has 2 tabs
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(getNumberOfWindows(), 2)
        }
    }

}
