//
//  URL+BeamTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/06/2021.
//

import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class URLBeamTest: XCTestCase {

    func testUrlStringByRemovingUnnecessaryCharacters() throws {
        let expectedWikipedia = "wikipedia.org"
        XCTAssertEqual(URL(string: "wikipedia.org/")?.urlStringByRemovingUnnecessaryCharacters, expectedWikipedia)
        XCTAssertEqual(URL(string: "https://wikipedia.org/")?.urlStringByRemovingUnnecessaryCharacters, expectedWikipedia)
        XCTAssertEqual(URL(string: "http://wikipedia.ORG?")?.urlStringByRemovingUnnecessaryCharacters, expectedWikipedia)
        XCTAssertEqual(URL(string: "https://en.wikipedia.org/post/1?lang=en")?.urlStringByRemovingUnnecessaryCharacters, "en.wikipedia.org/post/1?lang=en")
    }

    func testDomainMatchReturnsTrue_HavingCorrectDomain() throws {
        XCTAssertTrue(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia"))
        XCTAssertTrue(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia."))
        XCTAssertTrue(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia.org"))
        XCTAssertTrue(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia.org/"))

        XCTAssertTrue(URL(string: "https://wikipedia.org")!.domainMatchWith("wikipedia"))
        XCTAssertTrue(URL(string: "https://wikipedia.org")!.domainMatchWith("wikipedia."))
        XCTAssertTrue(URL(string: "https://wikipedia.org")!.domainMatchWith("wikipedia.org"))
    }

    func testDomainMatchReturnsFalse_QueryDidNotMatchDomain() {
        XCTAssertFalse(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia.org/w"))
        XCTAssertFalse(URL(string: "https://wikipedia.org/")!.domainMatchWith("wikipedia.f"))
        XCTAssertFalse(URL(string: "https://wikipedia.org/")!.domainMatchWith("wiki pedia"))
    }

    func testDomainMatchReturnsFalse_WhenDidNotMatchDomain() throws {
        XCTAssertFalse(URL(string: "https://wikipedia.org/wiki")!.domainMatchWith("wikipedia"))
        XCTAssertFalse(URL(string: "https://wikipedia.org/wiki")!.domainMatchWith("wikipedia."))
        XCTAssertFalse(URL(string: "https://wikipedia.org/wiki")!.domainMatchWith("wikipedia.org"))
        XCTAssertFalse(URL(string: "https://wikipedia.org/wiki")!.domainMatchWith("wikipedia.org/"))
    }

    func testUrlIsDomain_WhenHavingCorrectDomain() {
        XCTAssertTrue(URL(string: "https://wikipedia.org/")!.isDomain)
        XCTAssertTrue(URL(string: "https://www.wikipedia.org/")!.isDomain)
        XCTAssertTrue(URL(string: "https://wikipedia.org")!.isDomain)
        XCTAssertTrue(URL(string: "https://www.wikipedia.org")!.isDomain)
        XCTAssertTrue(URL(string: "https://wikipedia.customextension")!.isDomain)
        XCTAssertTrue(URL(string: "https://wikipedia.org/?hello=param")!.isDomain)
    }

    func testUrlIsNotDomain_WhenHavingIncorrectDomain() {
        XCTAssertFalse(URL(string: "https://wikipedia.org/wiki")!.isDomain)
        XCTAssertFalse(URL(string: "https://www.wikipedia.org/wiki")!.isDomain)
        XCTAssertFalse(URL(string: "https://wikipedia.org/page.html")!.isDomain)
    }
    func testBaseUrl() {
        XCTAssertEqual(URL(string: "https://www.wikipedia.org/wiki")?.domain, URL(string: "https://www.wikipedia.org/"))
        XCTAssertEqual(URL(string: "https://www.wikipedia.org")?.domain, URL(string: "https://www.wikipedia.org/"))
        XCTAssertNil(URL(string: "www.wikipedia.org/wiki")?.domain)
    }
}
