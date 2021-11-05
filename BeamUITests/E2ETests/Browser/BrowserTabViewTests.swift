//
//  BrowserTabViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 16.08.2021.
//

import Foundation
import XCTest

class BrowserTabViewTests: BaseTest {
    
    func testOpenCloseTabs() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)
        
        testRailPrint("Given I open a web page")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
        let webView = WebTestView()
        let uiTestPageLink = webView.staticText("new-tab-beam")
            
        testRailPrint("Then 1 tab is opened")
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)

        testRailPrint("When I open another from the link on the web page")
        uiTestPageLink.click()
        
        testRailPrint("Then 2 tabs are available")
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 2)

        testRailPrint("When I close 1 tab")
        webView.closeTab()
        
        testRailPrint("Then 1 tab is opened")
        XCTAssertEqual(webView.getNumberOfTabs(), 1)
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)

        testRailPrint("When I open tab using + icon")
        webView.openTab()
        
        testRailPrint("Then 2 tabs are available")
        XCTAssertEqual(webView.getNumberOfTabs(), 2)
        
        testRailPrint("When I close tabs")
        webView.closeTab()
        webView.closeTab()
        XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)

        testRailPrint("Then I'm redirected to Journal")
        XCTAssertTrue(WaitHelper().waitFor( WaitHelper.PredicateFormat.exists.rawValue, journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)))
    }
}
