//
//  BrowserHistoryTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 30.04.2022.
//

import Foundation
import XCTest

class BrowserHistoryTests: BaseTest {
    
    let omnibox = OmniBoxTestView()
    let linkToOpen = MockHTTPWebPages().getMockPageUrl(.ambiguousShortForm).dropLast()
    let url1 = MockHTTPWebPages().getMockPageUrl(.mainView)
    let url2 = MockHTTPWebPages().getMockPageUrl(.ambiguousShortForm)
    
    private func openPageByLinkClick() {
        webView.staticText(String(linkToOpen)).tapInTheMiddle()
    }
    
    private func openPageByContinueButtonClick() {
        webView.button("Continue").tapInTheMiddle()
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        uiMenu
            .destroyDB()
            .startMockHTTPServer()
    }
    
    private func openMultipleWebPagesInSameTab() {
        
        step("GIVEN I open multiple web pages in the same tab"){
            mockPage.openMockPage(.mainView)
            self.openPageByLinkClick()
            self.openPageByContinueButtonClick()
        }
    }
    
    func testBrowserHistoryNavigation() {
        
        openMultipleWebPagesInSameTab()
        let url3 = url2 + "view"
        
        step("THEN forward button is disabled and \(url2) is opened on browser history back button click"){
            XCTAssertFalse(webView.button(WebViewLocators.Buttons.goForwardButton.accessibilityIdentifier).exists)
            XCTAssertTrue(webView
                            .browseHistoryBackButtonClick().activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url1) is opened on CMD+[ shortcuts click and Back button is disabled"){
            shortcutHelper.shortcutActionInvoke(action: .browserHistoryBack)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url1))
            XCTAssertFalse(webView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).isEnabled)
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url2) is opened on browser history forward button click"){
            shortcutHelper.shortcutActionInvoke(action: .browserHistoryForward)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url3) is opened on CMD+] arrow shortcuts click"){
            XCTAssertTrue(webView
                            .browseHistoryForwardButtonClick().activateAndWaitForSearchFieldToEqual(url3))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url2) is opened on Go menu -> Back option"){
            GoMenu().goBack()
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url1) is opened on CMD+left arrow"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .browserHistoryBackArrow, numberOfTimes: 2)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url1))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url2) is opened on Go menu -> Forward option"){
            GoMenu().goForward()
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url3) is opened on CMD+right arrow"){
            shortcutHelper.shortcutActionInvokeRepeatedly(action: .browserHistoryForwardArrow, numberOfTimes: 2)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url3))
        }
        
    }
    
    func testCMDClickOnNavigationArrowOpensNewTab() {
        
        openMultipleWebPagesInSameTab()
        
        step("WHEN I CMD click on navigation arrow") {
            webView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).clickPressingKeyboardKey(.command)
        }
        
        step("THEN new tab is opened on correct web page") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertEqual(webView.getBrowserTabTitleValueByIndex(index: 1), "Sign In")
        }
    }
    
    
    func testDuplicatingTabDuplicatesHistory() {
        
        openMultipleWebPagesInSameTab()
        
        step("WHEN I duplicate a tab") {
            webView.openTabMenu(tabIndex: 0).selectTabMenuItem(.duplicateTab)
        }
        
        step("THEN it's history is also duplicated") {
            webView.waitForWebViewToLoad()
            XCTAssertEqual(webView.getNumberOfTabs(), 2)
            XCTAssertTrue(webView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
    
    
}
