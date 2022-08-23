//
//  GoogleSheetsTests.swift
//  BeamUITests
//
//  Created by Stef Kors on 03/02/2022.
//

import Foundation
import XCTest


class GoogleServicesTests: BaseTest {

    let omniboxView = OmniBoxTestView()

    let spreadsheetURL = "https://docs.google.com/spreadsheets/d/17hgmlXZWZEfjt-nxjvFL_Us3IYGpn8LsVe7SAJYTTjs/edit?usp=sharing"
    let docURL = "https://docs.google.com/document/d/194j8pkB9K9g4d8UBm29wlbO5K9hHbVJrFGLjj0haLJM/edit?usp=sharing"

    override func setUp() {
        launchApp()
    }
    
    func runTest(url: String, docTitle: String) {
        
        step("GIVEN I open Google sheet website: \(url)"){
            omniboxView.searchInOmniBox(url, true)
        }
        
        step("THEN \(docTitle) is successfully loaded"){
            
            webView.waitForWebViewToLoad()
            let unableToLoadError = webView.staticText("Unable to load file")
            
            XCTAssertFalse(unableToLoadError.waitForExistence(timeout: BaseTest.minimumWaitTimeout), "No alert should be shown")
            XCTAssertTrue(webView.staticText(docTitle).exists, "The document is not loaded") // it is also important the file is loaded as far as error message could be changed by Google
        }
    }

    func testGoogleSheetsFileLoading() {
        testrailId("C909")
        runTest(url: spreadsheetURL, docTitle: "Google spreadsheet")
    }
    
    func testGoogleDocFileLoading() {
        testrailId("C908")
        runTest(url: docURL, docTitle: "Google doc")
    }

}
