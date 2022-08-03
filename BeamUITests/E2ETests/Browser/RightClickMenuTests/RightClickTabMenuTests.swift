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
    
    func testCloseTabsToTheRight() throws {
        
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
    
    func testCloseOtherTabs() throws {
        
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
    
}
