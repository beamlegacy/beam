//
//  BrowserFancyUrlTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 17/02/2022.
//

import Foundation
import XCTest

class BrowserFancyUrlTests: BaseTest {
    
    func testFancyUrlOpening() throws {
        let omniboxTestView = OmniBoxTestView()
        let journalView = launchApp()

        let urlsToTest = [
            "localhost:3000",
            "www.nyxt.atlas.engineer",
            "www.julie.design",
            "www.anne.cafe",
            "www.amaZon.com" // checking if capital cases are handled
        ]
        
        var url: String?
        for urlToTest in urlsToTest {
            step("Given I open \(urlToTest) web page"){
                journalView.openWebsite(urlToTest)
                _ = webView.waitForWebViewToLoad()
            }
            step("Then Google is not launching a search"){
                shortcutHelper.shortcutActionInvoke(action: .openLocation)
                _ = omniboxTestView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
                url = omniboxTestView.getSearchFieldValue()
                XCTAssertFalse(url!.contains("google"))
                webView.typeKeyboardKey(.escape)
            }
            if (!urlToTest.contains("localhost")){ // localhost is http
                step("And \(urlToTest) is opened"){
                    // Verify that https is correctly added
                    XCTAssertTrue(url!.contains("https://" + urlToTest.lowercased()), "\(url!) does not contain \("https://" + urlToTest.lowercased())")
                }
            }
        }
    }
}
