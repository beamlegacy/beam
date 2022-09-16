//
//  OmniboxGoToTab.swift
//  BeamUITests
//
//  Created by Quentin Valero on 15/09/2022.
//

import Foundation
import XCTest

class OmniboxGoToTab: BaseTest {
    
    let omniboxView = OmniBoxTestView()
    
    func testGoToUnpinTab(){
        testrailId("C1184, C1185")
        
        step("Given I open multiple tabs in browser"){
            uiMenu.invoke(.loadUITestPage1)
            uiMenu.invoke(.loadUITestPage2)
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertTrue(webView.getTabByIndex(index: 1).isSelected)
        }
        
        step("And I search an already opened tab on omnibox from note"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(uiTestPageOne, true)
        }
        
        step("Then I am redirected to opened tab"){
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertTrue(webView.getTabByIndex(index: 0).isSelected)
        }
        
        step("When I go to a tab from web"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(uiTestPageTwo, true)
        }
        
        step("Then tab is selected"){
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertTrue(webView.getTabByIndex(index: 1).isSelected)
        }
    }
    
    func testGoToTabCollapsedGroup(){
        testrailId("C1186")
        let tabGroupMenu = TabGroupMenuView()
        
        step("Given I have a collapsed tab group"){
            createTabGroupAndSwitchToWeb()
            tabGroupMenu.collapseTabGroup(index: 0)
            XCTAssertEqual(webView.getNumberOfTabs(), 0)
        }
        
        step("And I search a tab contained in this tab group"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(uiTestPageTwo, true)
        }
        
        step("Then tab group is expanded and page is selected"){
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(webView.getTabByIndex(index: 1).isSelected)
        }
        
        step("When I collapse tab group and switch to note"){
            tabGroupMenu.collapseTabGroup(index: 0)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
        }
        
        step("And I search a tab from this collapsed tab group"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(uiTestPageTwo, true)
        }
        
        step("Then tab group is expanded and page is selected"){
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 4)
            XCTAssertTrue(webView.getTabByIndex(index: 1).isSelected)
        }
    }
    
    func testGoToTabPinTab(){
        testrailId("C1184, C1185")
        step("Given I have one pinned tab and one unpinned tab"){
            uiMenu.invoke(.loadUITestPage1)
            uiMenu.invoke(.loadUITestPage2)
            webView.openTabMenu(tabIndex: 0)
                .selectTabMenuItem(.pinTab)
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(), 1)
            XCTAssertTrue(webView.getTabByIndex(index: 1).isSelected)
        }
        
        step("And I search an already opened tab on omnibox from note"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox(uiTestPageOne, true)
        }
        
        step("Then I am redirected to pinned tab"){
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfPinnedTabs(), 1)
            XCTAssertEqual(webView.getNumberOfUnpinnedTabs(), 1)
            XCTAssertTrue(webView.getTabByIndex(index: 0).isSelected)
        }
    }
    
    func testGoToTabAndHistoryIcons(){
        testrailId("C1184, C1185, C1186")
        step("Given I have multiple tabs opened"){
            uiMenu.invoke(.loadUITestPage1)
            uiMenu.invoke(.loadUITestPage2)
            uiMenu.invoke(.loadUITestPage3)
        }
        
        step("And I search an already opened tab on omnibox from note"){
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point And Shoot Test", false)
            XCTAssertTrue(omniboxView.waitForAutocompleteResultsLoad(timeout: BaseTest.minimumWaitTimeout, expectedNumber: 8))
        }
        
        step("Then opened tab matching the search have Go To Tab icon"){
            XCTAssertTrue(omniboxView.isAutocompleteResultContainGoToTabIcon(autocompleteResult: uiTestPageOne))
            XCTAssertTrue(omniboxView.isAutocompleteResultContainGoToTabIcon(autocompleteResult: uiTestPageTwo))
            XCTAssertTrue(omniboxView.isAutocompleteResultContainGoToTabIcon(autocompleteResult: uiTestPageThree))
        }
        
        step("When I go to Test Page 1"){
            omniboxView.selectAutocompleteResult(autocompleteResult: uiTestPageOne)
        }
        
        step("And I search on omnibox from this tab"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
            omniboxView.searchInOmniBox("Point And Shoot Test", false)
        }
        
        step("Then Test Page 1 result has an history icon and others have a Go To Tab icon"){
            XCTAssertTrue(omniboxView.isAutocompleteResultContainHistoryIcon(autocompleteResult: uiTestPageOne))
            XCTAssertTrue(omniboxView.isAutocompleteResultContainGoToTabIcon(autocompleteResult: uiTestPageTwo))
            XCTAssertTrue(omniboxView.isAutocompleteResultContainGoToTabIcon(autocompleteResult: uiTestPageThree))
        }
    }
    
    func testCmdClickOnOpenedTabDoesNotGoToTab(){
        testrailId("C1184")
        let noteView = NoteTestView()
        let pnsView = PnSTestView()
        
        step("Given I open a tab and save it on a note"){
            uiMenu.invoke(.loadUITestPage1)
            shortcutHelper.shortcutActionInvoke(action: .collectFullPage)
            pnsView.waitForCollectPopUpAppear()
            pnsView.typeKeyboardKey(.enter)
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            noteView.waitForNoteViewToLoad()
        }
        
        step ("When I CMD+Click on the link of the tab"){
            XCUIElement.perform(withKeyModifiers: .command) {
                noteView.getTextNodes()[0].coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.5)).tap()
            }
        }
        
        step ("Then new tab is opened"){
            XCTAssertEqual(noteView.getPivotButtonCounter(), "2")
            shortcutHelper.shortcutActionInvoke(action: .switchBetweenNoteWeb)
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
        }
    }
}
