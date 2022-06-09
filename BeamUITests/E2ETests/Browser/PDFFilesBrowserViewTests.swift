//
//  PDFFilesBrowserView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 18.04.2022.
//

import Foundation
import XCTest

class PDFFilesBrowserViewTests: BaseTest {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        step("Given I start mock server") {
            launchApp()
            uiMenu.destroyDB()
                .startMockHTTPServer()
        }
    }
    
    override func tearDown() {
        step("Given I stop mock server") {
            uiMenu.stopMockHTTPServer()
            super.tearDown()
        }
    }
    
    func testPDFDocumentControls() {
        let expectedDefaultZoomRatio = "100%"
        
        step("When I open a PDF file") {
            MockHTTPWebPages().openMockPage(.testPdfFile)
        }
        
        step("Then I see print, download and zoom in/out buttons and correct zoom ratio value as") {
            XCTAssertTrue(webView.getPDFPrintButton().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertTrue(webView.getPDFDownloadButton().exists)
            XCTAssertTrue(webView.getPDFZoomInButton().exists)
            XCTAssertTrue(webView.getPDFZoomOutButton().exists)
            XCTAssertEqual(webView.getCurrentPDFZoomRatio(), expectedDefaultZoomRatio)
        }
        
        step("Then Print pop-up appears on Print button click") {
            webView.getPDFPrintButton().tapInTheMiddle()
            XCTAssertTrue(webView.getPrintPopupWindow().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            webView.cancelPDFPrintAction()
        }
        
        step("Then Zoom ratio is correctly changed on zoom in/out buttons click") {
            webView.getPDFZoomInButton().clickMultipleTimes(times: 3)
            XCTAssertEqual(webView.getCurrentPDFZoomRatio(), "300%")
            webView.getPDFZoomOutButton().clickMultipleTimes(times: 5)
            XCTAssertEqual(webView.getCurrentPDFZoomRatio(), "75%")
            webView.getPDFZoomInButton().clickMultipleTimes(times: 2)
            XCTAssertEqual(webView.getCurrentPDFZoomRatio(), expectedDefaultZoomRatio)
        }
    }
    
}
