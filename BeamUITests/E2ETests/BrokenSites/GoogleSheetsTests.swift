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
    let mapURL = "https://www.google.com/maps/place/Mt+Everest/@27.988119,86.9074655,14z/data=!3m1!4b1!4m5!3m4!1s0x39e854a215bd9ebd:0x576dcf806abbab2!8m2!3d27.9881206!4d86.9249751"
    let presentationURL = "https://docs.google.com/presentation/d/1ITjh9CNJOYCPLip0tm2UExC84vnpFwTLxWkIsEy3kX8/edit?usp=sharing"

    override func setUp() {
        launchApp()
    }
    
    private func openGoogleService(url: String) {
        step("GIVEN I open Google service website: \(url)"){
            omniboxView.searchInOmniBox(url, true)
        }
    }
    
    func runTest(url: String, docTitle: String) {
        step("THEN \(docTitle) is successfully loaded"){
            openGoogleService(url: url)
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
    
    func testGooglePresentationOpening() {
        testrailId("C910")
        runTest(url: presentationURL, docTitle: "Google presentation")
    }
    
    func testGoogleMapsOpening() throws {
        try XCTSkipIf(true, "The test to be ran locally due to flakiness when Google Alerts appear sometimes on GMaps opening")
        testrailId("C918")
        openGoogleService(url: mapURL)
        
        step("THEN the map web view is loaded dispalying expected web elements") {
            XCTAssertTrue(webView.webView("Mt Everest - Google Maps").waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            XCTAssertTrue(webView.staticText("Mt Everest").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
    }
}
