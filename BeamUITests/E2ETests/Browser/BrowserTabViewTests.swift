//
//  BrowserTabViewTests.swift
//  BeamUITests
//
//  Created by Andrii on 16.08.2021.
//

import Foundation
import XCTest

class BrowserTabViewTests: BaseTest {
    
    let linkToOpen = "released his perhaps still-in-progress album"
    let uiTestPage1Title = "Point And Shoot Test Fixture Ultralight Beam"
    var journalView: JournalTestView!
    
    override func setUp() {
        step("Given I open a web page"){
            journalView = launchApp()
            uiMenu.loadUITestPage1()
        }
        
    }
    
    func testOpenCloseTabs() {

        let uiTestPageLink = webView.staticText("new-tab-beam")
        
        step("Then 1 tab is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)
        }
        
        step("When I open another from the link on the web page"){
            uiTestPageLink.clickOnExistence()
        }
        
        step("Then 2 tabs are available"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 2)
        }

        step("When I close 1 tab"){
            webView.closeTab()
        }
        
        step("Then 1 tab is opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 1)
        }
        
        step("When I close tabs"){
            webView.closeTab()
        }

        step("Then I'm redirected to Journal"){
            XCTAssertTrue(waitFor( PredicateFormat.exists.rawValue, journalView.scrollView(JournalViewLocators.ScrollViews.journalScrollView.accessibilityIdentifier)))
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)
        }
        
    }
    
    func testOpenLinkInNewTab() { // BE-3783: crash when opening a tab with CMD+Click
        
        step("When I open a link with CMD+Click"){
            XCUIElement.perform(withKeyModifiers: .command) {
                XCUIApplication().webViews[uiTestPage1Title].staticTexts[linkToOpen].clickOnExistence()
            }
        }
        
        step("Then 2 tabs are opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 2)
        }
        
    }
}
