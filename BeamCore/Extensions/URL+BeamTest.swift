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
        XCTAssertEqual(URL(string: "http://wikipedia.ORG?")?.urlStringByRemovingUnnecessaryCharacters, "wikipedia.ORG")
        XCTAssertNotEqual(URL(string: "http://wikipedia.ORG?")?.urlStringByRemovingUnnecessaryCharacters, expectedWikipedia)
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

    func testDomain() {
        XCTAssertEqual(URL(string: "https://www.wikipedia.org/wiki")?.domain, URL(string: "https://wikipedia.org/"))
        XCTAssertEqual(URL(string: "https://www.wikipedia.org")?.domain, URL(string: "https://wikipedia.org/"))
        XCTAssertNil(URL(string: "www.wikipedia.org/wiki")?.domain)
    }

    func testSchemeAndHost() {
        XCTAssertEqual(URL(string: "http://google.com/")!.schemeAndHost, "http://google.com")
        XCTAssertEqual(URL(string: "http://google.com/search?proud")!.schemeAndHost, "http://google.com")
        XCTAssertEqual(URL(string: "http://www.google.com/search?proud")!.schemeAndHost, "http://www.google.com")
        XCTAssertEqual(URL(string: "http://search.somedomain.google.com/search?proud")!.schemeAndHost, "http://search.somedomain.google.com")
        XCTAssertEqual(URL(string: "http://google/search?proud")!.schemeAndHost, "http://google")
        XCTAssertNil(URL(string: "google/search?proud")!.schemeAndHost)
    }

    func testRootPathRemoved() {
        XCTAssertEqual(URL(string: "http://www.google.com/")!.rootPathRemoved.absoluteString, "http://www.google.com")
        XCTAssertEqual(URL(string: "http://www.google.com")!.rootPathRemoved.absoluteString, "http://www.google.com")
        XCTAssertEqual(URL(string: "http://www.google.com/search")!.rootPathRemoved.absoluteString, "http://www.google.com/search")
    }

    func testSameOrigin() {
        let firstUrl = URL(string: "http://www.example.com/dir/page.html")!

        //Same origin, other page
        XCTAssertTrue(URL(string: "http://www.example.com/dir/page2.html")!.isSameOrigin(as: firstUrl))
        //Same origin, other folder
        XCTAssertTrue(URL(string: "http://www.example.com/dir2/other.html")!.isSameOrigin(as: firstUrl))
        //Same origin, with username and password
        XCTAssertTrue(URL(string: "http://username:password@www.example.com/dir2/other.html")!.isSameOrigin(as: firstUrl))

        //Port changed
        XCTAssertFalse(URL(string: "http://www.example.com:81/dir/page.html")!.isSameOrigin(as: firstUrl))
        //Scheme changed
        XCTAssertFalse(URL(string: "https://www.example.com/dir/page.html")!.isSameOrigin(as: firstUrl))
        //Subdomain changed, different host
        XCTAssertFalse(URL(string: "http://en.example.com/dir/page.html")!.isSameOrigin(as: firstUrl))
        //Subdomain changed, different host
        XCTAssertFalse(URL(string: "http://example.com/dir/page.html")!.isSameOrigin(as: firstUrl))
        //Subdomain changed, different host
        XCTAssertFalse(URL(string: "http://v2.www.example.com/dir/page.html")!.isSameOrigin(as: firstUrl))
        //Port made explicit, this is a change
        XCTAssertFalse(URL(string: "http://www.example.com:80/dir/page.html")!.isSameOrigin(as: firstUrl))
    }
}
