//
//  BrowserOpenModalTests.swift
//  BeamUITests
//
//  Created by Stef Kors on 04/04/2022.
//

import XCTest

class BrowserOpenModalTests: BaseTest {

    let shortcutsHelper = ShortcutsHelper()
    let mockPage = MockHTTPWebPages()
    let uiMenuBar = UITestsMenuBar()
    let webView = WebTestView()
    let testPage = UITestPageBrowserWindow()

    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        uiMenuBar.destroyDB()
            .startMockHTTPServer()
    }

    func testOpenModalInNewWindowTHENNewTab() {
        step("WHEN the page has opened"){
            OmniBoxTestView().searchInOmniBox("http://windowopen.browser.lvh.me:8080/", true)
        }

        step("Given I tap on the open window button") {
            testPage.tapOpenWindow()
        }

        step("THEN I see two windows"){
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }

        step("Given I tap on the open tab button in the new window") {
            testPage.tapOpenTab()
        }

        step("THEN I see two tabs AND I see two windows"){
            // assert the minimal webview has no tabs
            // main window has 2 tabs
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }
    }

    func testOpenModalInNewWindowTHENNewTab_Async() {
        step("WHEN the page has opened"){
            OmniBoxTestView().searchInOmniBox("http://windowopen-async.browser.lvh.me:8080/", true)
        }

        step("Given I tap on the open window button") {
            testPage.tapOpenWindow()
        }

        step("THEN I see two windows"){
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }

        step("Given I tap on the open tab button in the new window") {
            testPage.tapOpenTab()
        }

        step("THEN I see two tabs AND I see two windows"){
            // assert the minimal webview has no tabs
            // main window has 2 tabs
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getNumberOfWindows(), 2)
        }
    }

}
