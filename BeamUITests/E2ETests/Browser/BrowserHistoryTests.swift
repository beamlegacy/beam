//
//  BrowserHistoryTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 30.04.2022.
//

import Foundation
import XCTest

class BrowserHistoryTests: BaseTest {
    
    let mockPage = MockHTTPWebPages()
    let uiMenuBar = UITestsMenuBar()
    let webView = WebTestView()
    let shortcuts = ShortcutsHelper()
    let omnibox = OmniBoxTestView()
    let linkToOpen = "http://ambiguous.form.lvh.me:8080"
    let url1 = "http://localhost:8080/"
    let url2 = "http://ambiguous.form.lvh.me:8080/"
    let url3 = "http://ambiguous.form.lvh.me:8080/view"
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp()
        uiMenuBar.destroyDB()
            .startMockHTTPServer()
    }
    
    private func openPageByLinkClick() {
        webView.staticText(linkToOpen).tapInTheMiddle()
    }
    
    private func openPageByContinueButtonClick() {
        webView.button("Continue").tapInTheMiddle()
    }
    
    func testBrowserHistoryNavigation() {
        
        step("GIVEN I open multiple web pages in the same tab"){
            OmniBoxTestView().searchInOmniBox("http://localhost:8080/", true)
            self.openPageByLinkClick()
            self.openPageByContinueButtonClick()
        }
        
        step("THEN forward button is disabled and \(url2) is opened on browser history back button click"){
            XCTAssertFalse(webView.button(WebViewLocators.Buttons.goForwardButton.accessibilityIdentifier).exists)
            XCTAssertTrue(webView
                            .browseHistoryBackButtonClick().activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url1) is opened on CMD+[ shortcuts click and Back button is disabled"){
            shortcuts.shortcutActionInvoke(action: .browserHistoryBack)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url1))
            XCTAssertFalse(webView.button(WebViewLocators.Buttons.goBackButton.accessibilityIdentifier).isEnabled)
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url2) is opened on browser history forward button click"){
            shortcuts.shortcutActionInvoke(action: .browserHistoryForward)
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
            shortcuts.shortcutActionInvokeRepeatedly(action: .browserHistoryBackArrow, numberOfTimes: 2)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url1))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url2) is opened on Go menu -> Forward option"){
            GoMenu().goForward()
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url2))
            webView.typeKeyboardKey(.escape) //unfocus omnibox
        }
        
        step("THEN \(url3) is opened on CMD+right arrow"){
            shortcuts.shortcutActionInvokeRepeatedly(action: .browserHistoryForwardArrow, numberOfTimes: 2)
            XCTAssertTrue(webView.activateAndWaitForSearchFieldToEqual(url3))
        }
        
    }
    
}
