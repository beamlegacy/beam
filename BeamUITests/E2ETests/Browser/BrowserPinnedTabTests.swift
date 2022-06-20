//
//  BrowserPinnedTabTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 08/06/2022.
//

import Foundation
import XCTest

class BrowserPinnedTabTests: BaseTest {
    
    let newTabToOpen = "google.com"
    var journalView: JournalTestView!
    var helper: BeamUITestsHelper!
    
    override func setUp() {
        step("Given I open a web page"){
            journalView = launchApp()
            helper = BeamUITestsHelper(journalView.app)
            helper.openTestPage(page: .page1)
        }
    }
    
    func testPinTab() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")
        
        step("When I pin the tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
        }
        
        step("Then tab is pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
        
        step("When I reload the pin tab"){
            ShortcutsHelper().shortcutActionInvoke(action: .reloadPage)
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
        
        step("When I open a new tab"){
            OmniBoxTestView().searchInOmniBox(newTabToOpen, true)
        }
        
        step("Then new tab is not pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
        }
    }
    
    func testUnpinTab() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")
        step("When I pin the tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
        }
        
        step("Then tab is pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
        
        step("When I unpin the tab"){
            webView.openTabMenu(tabIndex: 0, isPinnedTab: true).selectTabMenuItem(.unpinTab)
        }
        
        step("Then tab is unpinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 0)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
        }
    }
    
    func testPinMultipleTabs() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")
        step("And I open a second tab"){
            helper.openTestPage(page: .page1)
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 0)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
        }
        
        step("When I pin both tabs"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab) // new tab is now the first unpinned tab -> index 0
        }
                
        step("Then both tabs are pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 2)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
        
        step("When I unpin one tab"){
            webView.openTabMenu(tabIndex: 0, isPinnedTab: true).selectTabMenuItem(.unpinTab)
        }
        
        step("Then tab is unpinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
        }
    }
    
    func testPinnedTabAfterRestart() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")
        
        step("When I pin the tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
        }
        
        step("And I restart the app"){
            restartApp()
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
    }
    
    func testOpenLinkFromPinnedTab() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")
        let linkToOpen = "released his perhaps still-in-progress album"
        let uiTestPage1Title = "Point And Shoot Test Fixture Ultralight Beam"

        step("When I pin the tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
        }
        
        step("And I open a link with CMD+Click"){
            XCUIElement.perform(withKeyModifiers: .command) {
                XCUIApplication().webViews[uiTestPage1Title].staticTexts[linkToOpen].clickOnExistence()
            }
        }
        
        step("Then opened tab is not pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 1)
        }
    }
    
    func testRestorePinnedTab() throws {
        try XCTSkipIf(isBigSurOS(), "No accessibility to tab to right click on it")

        step("When I pin the tab"){
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.pinTab)
        }
        
        step("And I close the tab"){
            webView.openTabMenu(tabIndex: 0, isPinnedTab: true).selectTabMenuItem(.closeTab)
        }
        
        step("Then journal is displayed"){
            XCTAssertTrue(JournalTestView().isJournalOpened())
        }
        
        step("When I restore tabs"){
            shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 0)
        }
    }
}
