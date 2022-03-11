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
        let journalView = launchApp()

        let urlsToTest = [
            "localhost:3000",
            "nyxt.atlas.engineer",
            "julie.design",
            "anne.cafe",
            "amaZon.com" // checking if capital cases are handled
        ]
        for urlToTest in urlsToTest {
            testRailPrint("Given I open \(urlToTest) web page")
            let tab = journalView.openWebsite(urlToTest)
            testRailPrint("Then Google is not launching a search")
            XCTAssertFalse(tab.getTabUrlAtIndex(index: 0).contains("google"))
            if (!urlToTest.contains("localhost")){ // localhost is http
                testRailPrint("And \(urlToTest) is opened")
                XCTAssertEqual(tab.getTabUrlAtIndex(index: 0), urlToTest.lowercased() + "/")
            }
        }
    }
}
