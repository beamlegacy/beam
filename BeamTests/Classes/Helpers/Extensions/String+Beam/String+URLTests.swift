//
//  String+URL.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 05/03/2021.
//

import Foundation

import XCTest
@testable import Beam
@testable import BeamCore

class String_URLTests: XCTestCase {
    func testMarkdownizedURL() {
        XCTAssertEqual(String("http://lemonde.fr/test()someUrl").markdownizedURL, "http://lemonde.fr/test%28%29someUrl")
    }

    func testUrlString() {
        XCTAssertNil("prout".urlString)
        XCTAssertNil("".urlString)
        XCTAssertNil("some garbage".urlString)

        XCTAssertEqual("lemonde.fr".urlString, URL(string: "lemonde.fr"))
        XCTAssertEqual("lemonde.fr/truc".urlString, URL(string: "lemonde.fr/truc"))
        XCTAssertEqual("http://lemonde.fr".urlString, URL(string: "http://lemonde.fr"))
        XCTAssertEqual("http://lemonde.fr/truc".urlString, URL(string: "http://lemonde.fr/truc"))
        XCTAssertEqual("https://lemonde.fr".urlString, URL(string: "https://lemonde.fr"))
        XCTAssertEqual("https://lemonde.fr/truc".urlString, URL(string: "https://lemonde.fr/truc"))
    }

    func testUrlRangesInside() {
        XCTAssertEqual("prout".urlRangesInside(), [])
        XCTAssertEqual("".urlRangesInside(), [])
        XCTAssertEqual("some garbage".urlRangesInside(), [])

        XCTAssertEqual("lemonde.fr".urlRangesInside(), [NSRange(location: 0, length: 10)])
        XCTAssertEqual("blahb laah lemonde.fr/truc hop foo bar!".urlRangesInside(), [NSRange(location: 11, length: 15)])
        XCTAssertEqual("blahb laah lemonde.fr/truc hop https foo bar!".urlRangesInside(), [NSRange(location: 11, length: 15)])
        XCTAssertEqual("blahb laah lemonde.fr/truc hop https:// foo bar!".urlRangesInside(), [NSRange(location: 11, length: 15)])
        XCTAssertEqual("blahb laah lemonde.fr/truc hop https://foobar!/yay truc".urlRangesInside(), [NSRange(location: 11, length: 15), NSRange(location: 31, length: 19)])
    }

    func testValidURL() {
        let (res1, url1) = "http://apple.com".validUrl()
        XCTAssertTrue(res1)
        XCTAssertEqual(url1, "http://apple.com")

        let (res2, url2) = "apple.com".validUrl()
        XCTAssertTrue(res2)
        XCTAssertEqual(url2, "http://apple.com")

        let (res3, url3) = "apple".validUrl()
        XCTAssertFalse(res3)
        XCTAssertEqual(url3, "")
    }

    func testURLMinimizeHost() {
        XCTAssertEqual(URL(string: "http://google.com/search?prout")!.minimizedHost, "google.com")
        XCTAssertEqual(URL(string: "http://www.google.com/search?prout")!.minimizedHost, "google.com")
        XCTAssertEqual(URL(string: "http://search.somedomain.google.com/search?prout")!.minimizedHost, "search.somedomain.google.com")
        XCTAssertEqual(URL(string: "http://google/search?prout")!.minimizedHost, "google")
        XCTAssertNil(URL(string: "google/search?prout")!.minimizedHost)
    }

    func testUrlIsSearchResult() {
        XCTAssertTrue(URL(string: "http://google.com/search?prout")!.isSearchResult)
        XCTAssertTrue(URL(string: "http://google.com/url?prout")!.isSearchResult)
        XCTAssertFalse(URL(string: "http://groogle.com/search?prout")!.isSearchResult)
        XCTAssertFalse(URL(string: "http://google.com/blop?prout")!.isSearchResult)
    }

    func testUrlWithScheme() {
        XCTAssertEqual(URL(string: "http://google.com/testing")!.urlWithScheme.absoluteString, "http://google.com/testing")
        XCTAssertEqual(URL(string: "test://www.google.com/testing")!.urlWithScheme.absoluteString, "test://www.google.com/testing")
        XCTAssertEqual(URL(string: "google.com/testing")!.urlWithScheme.absoluteString, "https://google.com/testing")
        XCTAssertEqual(URL(string: "google")!.urlWithScheme.absoluteString, "https://google")
    }

    func testUrlWithoutScheme() {
        XCTAssertEqual(URL(string: "http://google.com/testing")!.urlStringWithoutScheme, "google.com/testing")
        XCTAssertEqual(URL(string: "http://www.google.com/testing")!.urlStringWithoutScheme, "google.com/testing")
        XCTAssertEqual(URL(string: "google.com/testing")!.urlStringWithoutScheme, "google.com/testing")
        XCTAssertEqual(URL(string: "google")!.urlStringWithoutScheme, "google")
    }
}
