//
//  GoogleSheetsTests.swift
//  BeamUITests
//
//  Created by Stef Kors on 03/02/2022.
//

import Foundation
import XCTest


class GoogleSheetsTests: BaseTest {

    let waitHelper = WaitHelper()
    let omniboxView = OmniBoxTestView()

    let url = "https://docs.google.com/spreadsheets/d/1bOh2DVaDn9M8ihPDysgpBt0ewVaLsWbJGBRcC8ZqTF8/edit?usp=sharing"

    override func setUpWithError() throws {
        XCUIApplication().launch()
    }

    func testGoogleSheetsIsUnableToLoadFile() throws {
        testRailPrint("Given I open website: \(url)")
        let webView = omniboxView.searchInOmniBox(url, true)
        testRailPrint("Then browser tab bar appears")
        XCTAssertTrue(webView.getAnyTab().waitForExistence(timeout: implicitWaitTimeout))
        let textElement = XCUIApplication().windows.staticTexts["Unable to load file"].firstMatch
        XCTAssertTrue(waitHelper.waitForDoesntExist(textElement), "No alert should be shown")
    }

}
