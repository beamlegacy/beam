//
//  String+RegexTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 31/05/2021.
//

import XCTest

class StringRegexTests: XCTestCase {

    let validWebURLs = ["swift.fr", "http://swift.fr", "http://SwIft.Fr", "http://the-super--swift.fr"]
    let validFileURLs = ["file:///swift.beamappfile", "file:///path/to/swift.html", "file:///some-dir/some-swift--file.html"]
    let validEmails = ["swift@beamapp.co", "s@b.co", "john-swift--the3rd@beamapp.co"]

    let invalidWebURLs = ["http://swift", "swift"]
    let invalidFileURLs = ["file://swift.html", "file://path/swift.html", "file"]
    let invalidEmails = ["swift", "https://swift", "@swift.co", "mailto:swift@beamapp.co", "swift@beamapp.co:wrong"]

    func testMayBeURL() {
        for validWebURL in validWebURLs {
            XCTAssertTrue(validWebURL.mayBeURL, "\(validWebURL) should be a valid URL")
        }
        for validFileURL in validFileURLs {
            XCTAssertTrue(validFileURL.mayBeURL, "\(validFileURL) should be a valid URL")
        }

        for invalidWebURL in invalidWebURLs {
            XCTAssertFalse(invalidWebURL.mayBeURL, "\(invalidWebURL) should not be a valid URL")
        }
        for invalidFileURL in invalidFileURLs {
            XCTAssertFalse(invalidFileURL.mayBeURL, "\(invalidFileURL) should not be a valid URL")
        }
    }

    func testMayBeWebURL() {
        for validWebURL in validWebURLs {
            XCTAssertTrue(validWebURL.mayBeWebURL, "\(validWebURL) should be a valid Web URL")
        }

        for invalidWebURL in invalidWebURLs {
            XCTAssertFalse(invalidWebURL.mayBeWebURL, "\(invalidWebURL) should not be valid Web URL")
        }
    }

    func testMayBeFileURL() {
        for validFileURL in validFileURLs {
            XCTAssertTrue(validFileURL.mayBeFileURL, "\(validFileURL) should be a valid file URL")
        }

        for invalidFileURL in invalidFileURLs {
            XCTAssertFalse(invalidFileURL.mayBeFileURL, "\(invalidFileURL) should not be a valid file URL")
        }
    }

    func testMayBeEmail() {
        for validEmail in validEmails {
            XCTAssertTrue(validEmail.mayBeEmail, "\(validEmail) should be a valid email")
        }

        for invalidEmail in invalidEmails {
            XCTAssertFalse(invalidEmail.mayBeEmail, "\(invalidEmail) should not be a valid email")
        }
    }

}
