//
//  String+RegexTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 31/05/2021.
//

import XCTest

class StringRegexTests: XCTestCase {

    let validWebURLs = ["swift.fr", "http://swift.fr", "http://SwIft.Fr", "http://the-super--swift.fr", "https://atlas.engineer", "https://swift.org/רפאל_נדאל"]
    let validFileURLs = ["file:///swift.beamappfile", "file:///path/to/swift.html", "file:///some-dir/some-swift--file.html"]
    let validEmails = ["swift@beamapp.co", "s@b.co", "john-swift--the3rd@beamapp.co"]
    let validUsernames = ["tyler", "tyler_joseph", "josh-dun-09", "ty", "username20characters"]

    let invalidWebURLs = ["thhs://swift", "swift", "file://swift.html"]
    let invalidFileURLs = ["file://swift.html", "file://path/swift.html", "file"]
    let invalidEmails = ["swift", "https://swift", "@swift.co", "mailto:swift@beamapp.co", "swift@beamapp.co:wrong"]
    let invalidUsernames = ["tyler joseph", "tyler.joseph", "t", "usernameislongerthan30characters", ""]

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

    let emailPattern = "([a-z0-9_\\.-]+)@([a-z0-9-_]+)(\\.[a-z0-9_\\.-]+)*(\\.[a-z0-9]{2,10})"
    func testCapturedGroups() {
        let email = "macos@beamapp.co.uk"
        let result = email.capturedGroups(withRegex: emailPattern)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], "macos")
        XCTAssertEqual(result[1], "beamapp")
        XCTAssertEqual(result[2], ".co")
        XCTAssertEqual(result[3], ".uk")
    }

    func testCapturedGroupAtIndex() {
        let email = "macos@beamapp.co.uk"
        let result = email.capturedGroup(withRegex: emailPattern, groupIndex: 1)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "beamapp")

        XCTAssertNil("something@.co".capturedGroup(withRegex: emailPattern, groupIndex: 0))
        XCTAssertNil("something@beamapp.co".capturedGroup(withRegex: emailPattern, groupIndex: 5))
    }

    func testMatches() {
        XCTAssertTrue("macos@beamapp.co".matches(withRegex: emailPattern))
        XCTAssertTrue("a@b.co".matches(withRegex: emailPattern))
        XCTAssertFalse("a@co".matches(withRegex: emailPattern))
        XCTAssertFalse("macosbeamapp.co".matches(withRegex: emailPattern))
    }

    func testMayBeUsername() {
        for validUsername in validUsernames {
            XCTAssertTrue(validUsername.mayBeUsername, "\(validUsername) should be a valid username")
        }

        for invalidUsername in invalidUsernames {
            XCTAssertFalse(invalidUsername.mayBeUsername, "\(invalidUsername) should not be a valid username")
        }
    }
}
