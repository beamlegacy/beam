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
        let webView = WebTestView()
        
        step("Given I open a web page"){
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.page1)
            
        }
        
        let uiTestPageLink = webView.staticText("new-tab-beam")
        
        step("Then 1 tab is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)
        }


        step("When I open another from the link on the web page"){
            uiTestPageLink.click()
        }
        
        step("Then 2 tabs are available"){
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 2)
        }

        step("When I close 1 tab"){
            webView.closeTab()
        }
        
        step("Then 1 tab is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(), 1)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)
        }
        
        step("When I close tabs"){
            webView.closeTab()
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)
        }

        step("Then I'm redirected to Journal"){
            XCTAssertTrue(waitFor( PredicateFormat.exists.rawValue, journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)))

        }
    }
}
