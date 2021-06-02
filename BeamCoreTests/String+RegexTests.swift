//
//  String+RegexTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 31/05/2021.
//

import XCTest

class String_RegexTests: XCTestCase {

    let validWebURLs = ["swift.fr", "http://swift.fr", "http://SwIft.Fr"]
    let validFileURLs = ["file:///swift.beamappfile", "file:///path/to/swift.html"]

    let invalidWebURLs = ["http://swift", "swift"]
    let invalidFileURLs = ["file://swift.html", "file://path/swift.html", "file"]

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

}
//file:///Users/remi/Projects/remstos.github.io/index.html
