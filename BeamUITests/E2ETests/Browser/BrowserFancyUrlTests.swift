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
            "www.anne.cafe",
            "nyxt.atlas.engineer",
            "www.julie.design",
            "www.amaZon.com" // checking if capital cases are handled
        ]
        
        var url: String?

        for urlToTest in urlsToTest {
            step("Given I open \(urlToTest) web page"){
                journalView.openWebsite(urlToTest)
                webView.waitForWebViewToLoad()
            }
            step("Then Google is not launching a search"){
                shortcutHelper.shortcutActionInvoke(action: .openLocation)
                _ = omniboxTestView.getOmniBoxSearchField().waitForExistence(timeout: BaseTest.implicitWaitTimeout)
                url = omniboxTestView.getSearchFieldValue()
                XCTAssertFalse(url!.contains("google"))
                webView.typeKeyboardKey(.escape)
            }

            step("Then \(urlToTest) is opened with https/http is correctly added") {
                let lowercasedUrl = urlToTest.lowercased()
                XCTAssertTrue(url!.contains("https://" + lowercasedUrl) || url!.contains("http://" + lowercasedUrl), "\(url!) does not contain \("https://" + lowercasedUrl) OR \("http://" + lowercasedUrl)")
            }
        }
    }
}
