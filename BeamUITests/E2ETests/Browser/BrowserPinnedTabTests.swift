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
    
    override func setUp() {
        step("Given I open a web page"){
            journalView = launchApp()
            uiMenu.loadUITestPage1()
        }
    }
    
    private func pinFirstTabStep() {
        step("When I pin the tab"){
            webView
                .openTabMenu(tabIndex: 0)
                .selectTabMenuItem(.pinTab)
        }
    }
    
    func testPinTab() throws {
        testrailId("C968")
        pinFirstTabStep()
        
        step("Then tab is pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
        }
        
        step("When I reload the pin tab"){
            ShortcutsHelper().shortcutActionInvoke(action: .reloadPage)
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
        }
        
        step("When I open a new tab"){
            shortcutHelper.shortcutActionInvoke(action: .newTab)
            OmniBoxTestView().searchInOmniBox(newTabToOpen, true)
        }
        
        step("Then new tab is not pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 1)
        }
    }
    
    func testUnpinTab() throws {
        testrailId("C969")
        pinFirstTabStep()
        
        step("Then tab is pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
        }
        
        step("When I unpin the tab"){
            webView.openTabMenu(tabIndex: 0, isPinnedTab: true).selectTabMenuItem(.unpinTab)
        }
        
        step("Then tab is unpinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 0)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 1)
        }
    }
    
    func testPinMultipleTabs() throws {
        testrailId("C968")
        step("And I open a second tab"){
            uiMenu.loadUITestPage2()
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 0)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 2)
        }
        
        step("When I pin both tabs"){
            webView
                .openTabMenu(tabIndex: 0)
                .selectTabMenuItem(.pinTab)
                .openTabMenu(tabIndex: 1)
                .selectTabMenuItem(.pinTab) // new tab is now the first unpinned tab -> index 0
        }
                
        step("Then both tabs are pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 2)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
        }
        
        testrailId("C969")
        step("When I unpin one tab"){
            webView
                .openTabMenu(tabIndex: 0, isPinnedTab: true)
                .selectTabMenuItem(.unpinTab)
        }
        
        step("Then tab is unpinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 1)
        }
    }
    
    func testPinnedTabAfterRestart() throws {
        testrailId("C1046")
        step("When I pin the tab"){
            webView
                .openTabMenu(tabIndex: 0)
                .selectTabMenuItem(.pinTab)
        }

        step("And enable start on opened tabs"){
            UITestsMenuBar().setStartBeamOnTabs(true)
        }
        
        step("And I restart the app"){
            restartApp()
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
            UITestsMenuBar().setStartBeamOnTabs(false)
        }
    }
    
    func testOpenLinkFromPinnedTab() throws {
        testrailId("C1047")
        let linkToOpen = "released his perhaps still-in-progress album"
        pinFirstTabStep()
        
        step("And I open a link with CMD+Click"){
            XCUIElement.perform(withKeyModifiers: .command) {
                XCUIApplication().webViews[uiTestPageOne].staticTexts[linkToOpen].clickOnExistence()
            }
        }
        
        step("Then opened tab is not pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 1)
        }
    }
    
    func testRestorePinnedTab() throws {
        testrailId("C1048")
        pinFirstTabStep()
        
        step("And I close the tab"){
            webView
                .openTabMenu(tabIndex: 0, isPinnedTab: true)
                .selectTabMenuItem(.closeTab)
        }
        
        step("Then journal is displayed"){
            XCTAssertTrue(journalView.isJournalOpened())
        }
        
        step("When I restore tabs"){
            shortcutHelper.shortcutActionInvoke(action: .reOpenClosedTab)
        }
        
        step("Then tab is still pinned"){
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(wait: true), 0)
        }
    }
}
