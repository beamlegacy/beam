//
//  GoogleSheetsTests.swift
//  BeamUITests
//
//  Created by Stef Kors on 03/02/2022.
//

import Foundation
import XCTest


class GoogleSheetsTests: BaseTest {

    let omniboxView = OmniBoxTestView()

    let url = "https://docs.google.com/spreadsheets/d/1bOh2DVaDn9M8ihPDysgpBt0ewVaLsWbJGBRcC8ZqTF8/edit?usp=sharing"

    override func setUpWithError() throws {
        XCUIApplication().launch()
    }

    func testGoogleSheetsIsUnableToLoadFile() throws {
        var webView: WebTestView?
        step("Given I open website: \(url)"){
            webView = omniboxView.searchInOmniBox(url, true)
        }
        step("Then browser tab bar appears"){
            XCTAssertTrue(webView!.getAnyTab().waitForExistence(timeout: BaseTest.implicitWaitTimeout))
            let textElement = XCUIApplication().windows.staticTexts["Unable to load file"].firstMatch
            XCTAssertTrue(waitForDoesntExist(textElement), "No alert should be shown")
        }
    }

}
