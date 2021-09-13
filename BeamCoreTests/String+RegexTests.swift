//
//  String+RegexTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 31/05/2021.
//

import XCTest

class StringRegexTests: XCTestCase {

    let validWebURLs = ["swift.fr", "http://swift.fr", "http://SwIft.Fr"]
    let validFileURLs = ["file:///swift.beamappfile", "file:///path/to/swift.html"]
    let validEmails = ["swift@beamapp.co", "s@b.co"]

    let invalidWebURLs = ["http://swift", "swift"]
    let invalidFileURLs = ["file://swift.html", "file://path/swift.html", "file"]
    let invalidEmails = ["swift", "https://swift", "@swift.co", "mailto:swift@beamapp.co", "swift@beamapp.co:wrong"]

    func testMayBeURL() {
        XCTAssertTrue(validWebURLs[0].mayBeURL)
        XCTAssertTrue(validWebURLs[1].mayBeURL)
        XCTAssertTrue(validWebURLs[2].mayBeURL)
        XCTAssertTrue(validFileURLs[0].mayBeURL)
        XCTAssertTrue(validFileURLs[1].mayBeURL)

        XCTAssertFalse(invalidWebURLs[0].mayBeURL)
        XCTAssertFalse(invalidWebURLs[1].mayBeURL)
        XCTAssertFalse(invalidFileURLs[0].mayBeURL)
        XCTAssertFalse(invalidFileURLs[1].mayBeURL)
        XCTAssertFalse(invalidFileURLs[2].mayBeURL)
    }

    func testMayBeWebURL() {
        XCTAssertTrue(validWebURLs[0].mayBeWebURL)
        XCTAssertTrue(validWebURLs[1].mayBeWebURL)
        XCTAssertTrue(validWebURLs[2].mayBeWebURL)

        XCTAssertFalse(invalidWebURLs[0].mayBeWebURL)
        XCTAssertFalse(invalidWebURLs[1].mayBeWebURL)
    }

    func testMayBeFileURL() {
        XCTAssertTrue(validFileURLs[0].mayBeFileURL)
        XCTAssertTrue(validFileURLs[1].mayBeFileURL)

        XCTAssertFalse(invalidFileURLs[0].mayBeFileURL)
        XCTAssertFalse(invalidFileURLs[1].mayBeFileURL)
        XCTAssertFalse(invalidFileURLs[2].mayBeFileURL)
    }

    func testMayBeEmail() {
        XCTAssertTrue(validEmails[0].mayBeEmail)
        XCTAssertTrue(validEmails[1].mayBeEmail)

        XCTAssertFalse(invalidEmails[0].mayBeEmail)
        XCTAssertFalse(invalidEmails[1].mayBeEmail)
        XCTAssertFalse(invalidEmails[2].mayBeEmail)
        XCTAssertFalse(invalidEmails[3].mayBeEmail)
        XCTAssertFalse(invalidEmails[4].mayBeEmail)
    }

}
