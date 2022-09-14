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
    var journalView: JournalTestView!
    
    override func setUp() {
        step("Given I open a web page"){
            journalView = launchApp()
            uiMenu.invoke(.loadUITestPage1)
        }
    }
    
    func testOpenCloseTabs() {
        testrailId("C965, C1050")
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
            XCTAssertTrue(waitFor( PredicateFormat.exists.rawValue, journalView.getScrollViewElement()))
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 0)
        }
    }
    
    func testOpenLinkInNewTab() { // BE-3783: crash when opening a tab with CMD+Click
        testrailId("C1049")
        step("When I open a link with CMD+Click"){
            XCUIElement.perform(withKeyModifiers: .command) {
                XCUIApplication().webViews[uiTestPageOne].staticTexts[linkToOpen].clickOnExistence()
            }
        }
        
        step("Then 2 tabs are opened"){
            XCTAssertEqual(webView.getNumberOfTabs(wait: true), 2)
            XCTAssertEqual(webView.getNumberOfWebViewInMemory(), 2)
        }
    }
    
    func testDragAndDropBrowserTabs() {
        testrailId("C972")
        let tabTitlesAfterDragAndDrop = [
            uiTestPageTwo,
            uiTestPageThree,
            uiTestPageOne
        ]
        
        step("GIVEN I open another web page"){
            //uiMenu.resizeWindowLandscape() required for the step to merge windows
            uiMenu.invoke(.loadUITestPage2)
                .invoke(.loadUITestPage3)
        }

        step("THEN the tabs order is successfully changed on drag'n'drop"){
            webView.dragTabToOmniboxIconArea(tabIndex: 0)
            XCTAssertTrue(webView.areTabsInCorrectOrder(tabs: tabTitlesAfterDragAndDrop))
        }
        
        step("THEN new window is opened when drag'n'drop a tap outside the tab bar"){
            webView.dragAndDropTabToElement(tabIndex: 2, elementToDragTo: webView.webView(tabTitlesAfterDragAndDrop[2]))
            XCTAssertTrue(waitForQueryCountEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 2, query: getWindowsQuery()), "Second window wasn't opened during \(BaseTest.implicitWaitTimeout) seconds timeout")
            XCTAssertEqual(self.getNumberOfTabInWindowIndex(index: 0), 1)
            XCTAssertEqual(self.getNumberOfTabInWindowIndex(index: 1), 2)
        }
        
        //Merge windows steps is too flaky, commented out to be ran locally if needed
        /*step("THEN tab is successfully dragged back to initial window") {
            uiMenu.resizeWindowPortrait()
            webView.dragAndDropTabToElement(tabIndex: 0, elementToDragTo: webView.app.windows[tabTitlesAfterDragAndDrop[0]].groups.matching(identifier: tabTitlesAfterDragAndDrop[0]).firstMatch)
            XCTAssertTrue(waitForQueryCountEqual(timeout: BaseTest.implicitWaitTimeout, expectedNumber: 1, query: getNumberOfWindows()), "Second window wasn't closed during \(BaseTest.implicitWaitTimeout) seconds timeout")
            XCTAssertEqual(webView.getNumberOfTabs(), 3)
        }*/
    }
    
}
