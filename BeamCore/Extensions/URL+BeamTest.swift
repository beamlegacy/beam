//
//  URL+BeamTest.swift
//  BeamTests
//
//  Created by Stef Kors on 21/06/2021.
//

import XCTest

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
        XCTAssertEqual(URL(string: "https://www.wikipedia.org/wiki")?.domain, URL(string: "https://www.wikipedia.org/"))
        XCTAssertEqual(URL(string: "https://www.wikipedia.org")?.domain, URL(string: "https://www.wikipedia.org/"))
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

    func testRootPathAdded() {
        XCTAssertEqual(URL(string: "http://www.google.com/")!.withRootPath.absoluteString, "http://www.google.com/")
        XCTAssertEqual(URL(string: "http://www.google.com")!.withRootPath.absoluteString, "http://www.google.com/")
        XCTAssertEqual(URL(string: "http://www.google.com/search")!.withRootPath.absoluteString, "http://www.google.com/search")
    }

    func testReplaceScheme() {
        XCTAssertEqual(
            URL(string: "http://example.com/dir/page.html")?.replacingScheme(with: "beam-wsh").absoluteString,
            "beam-wsh://example.com/dir/page.html"
        )
    }

    func testDomainPath0() {
        XCTAssertEqual(URL(string: "http://www.website.com?q=blah#anchor")!.domainPath0?.absoluteString, "http://www.website.com/")
        XCTAssertEqual(URL(string: "http://www.website.com/part1?q=blah#anchor")!.domainPath0?.absoluteString, "http://www.website.com/part1")
        XCTAssertEqual(URL(string: "http://www.website.com/part1/part2?q=blah#anchor")!.domainPath0?.absoluteString, "http://www.website.com/part1")
    }

    func testIsSearchEngineResultPage() {
        XCTAssertTrue(URL(string: "https://www.google.de/search?q=berlin&source=hp&ei=gNApYvHrN4Hear_Fq9gD&")!.isSearchEngineResultPage)
        XCTAssertFalse(URL(string: "https://www.google.com/maps/@48.8457835,2.3827251,14z")!.isSearchEngineResultPage)
        XCTAssertTrue(URL(string: "https://www.bing.com/search?q=cheval&search=&form=QBLH&sp=-1&pq=cheval&sc=8-6&qs=n&sk=")!.isSearchEngineResultPage)
        XCTAssertFalse(URL(string: "https://www.bing.com/shop?FORM=Z9LHS4")!.isSearchEngineResultPage)
        XCTAssertTrue(URL(string: "https://www.ecosia.org/search?method=index&q=donald+duck")!.isSearchEngineResultPage)
        XCTAssertFalse(URL(string: "https://info.ecosia.org/what")!.isSearchEngineResultPage)
        XCTAssertTrue(URL(string: "https://duckduckgo.com/?q=sevilla")!.isSearchEngineResultPage)
        XCTAssertFalse(URL(string: "https://duckduckgo.com/")!.isSearchEngineResultPage)
    }

    func testShortString() {
        let urlString = "http://www.awesome.site.co.uk/page?x=abcdef&y=ghijkl"
        XCTAssertEqual(URL(string: urlString)!.shortString(), "awesome.s..&y=ghijkl")
        XCTAssertEqual(URL(string: urlString)!.shortString(maxLength: 6), "aw..kl")
        XCTAssertEqual(URL(string: urlString)!.shortString(maxLength: 2000), "awesome.site.co.uk/page?x=abcdef&y=ghijkl")

    }
}
