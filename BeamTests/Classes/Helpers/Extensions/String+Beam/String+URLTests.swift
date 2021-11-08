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
        XCTAssertEqual(String("http://wikipedia.org/test()someUrl").markdownizedURL, "http://wikipedia.org/test%28%29someUrl")
    }

    func testToEncodedURL() {
        XCTAssertNil("something".toEncodedURL)
        XCTAssertNil("".toEncodedURL)
        XCTAssertNil("some space".toEncodedURL)

        XCTAssertEqual("wikipedia.org".toEncodedURL, URL(string: "wikipedia.org"))
        XCTAssertEqual("wikipedia.org/truc".toEncodedURL, URL(string: "wikipedia.org/truc"))
        XCTAssertEqual("http://wikipedia.org".toEncodedURL, URL(string: "http://wikipedia.org"))
        XCTAssertEqual("http://wikipedia.org/truc".toEncodedURL, URL(string: "http://wikipedia.org/truc"))
        XCTAssertEqual("https://wikipedia.org".toEncodedURL, URL(string: "https://wikipedia.org"))
        XCTAssertEqual("https://wikipedia.org/truc".toEncodedURL, URL(string: "https://wikipedia.org/truc"))
        XCTAssertEqual("https://wikipedia.org/truc?param=one&other=2".toEncodedURL, URL(string: "https://wikipedia.org/truc?param=one&other=2"))
        XCTAssertEqual("https://he.wikipedia.org/wiki/רפאל_נדאל".toEncodedURL, URL(string: "https://he.wikipedia.org/wiki/%D7%A8%D7%A4%D7%90%D7%9C_%D7%A0%D7%93%D7%90%D7%9C"))
        XCTAssertEqual("https://ru.wikipedia.org/wiki/Надаль,_Рафаэль".toEncodedURL, URL(string: "https://ru.wikipedia.org/wiki/%D0%9D%D0%B0%D0%B4%D0%B0%D0%BB%D1%8C,_%D0%A0%D0%B0%D1%84%D0%B0%D1%8D%D0%BB%D1%8C"))
        XCTAssertEqual("https://ary.wikipedia.org/wiki/رافاييل_نادال".toEncodedURL, URL(string: "https://ary.wikipedia.org/wiki/%D8%B1%D8%A7%D9%81%D8%A7%D9%8A%D9%8A%D9%84_%D9%86%D8%A7%D8%AF%D8%A7%D9%84"))

        // already encoded doesn't loose encoding :
        XCTAssertEqual("https://he.wikipedia.org/wiki/%D7%A8%D7%A4%D7%90%D7%9C_%D7%A0%D7%93%D7%90%D7%9C".toEncodedURL, URL(string: "https://he.wikipedia.org/wiki/%D7%A8%D7%A4%D7%90%D7%9C_%D7%A0%D7%93%D7%90%D7%9C"))
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
        XCTAssertEqual(url2, "https://apple.com")

        let (res3, url3) = "apple".validUrl()
        XCTAssertFalse(res3)
        XCTAssertEqual(url3, "")

        let (res4, url4) = "mailto:tim@apple.com".validUrl()
        XCTAssertTrue(res4)
        XCTAssertEqual(url4, "mailto:tim@apple.com")

        let (res5, url5) = "tim@apple.com".validUrl()
        XCTAssertTrue(res5)
        XCTAssertEqual(url5, "mailto:tim@apple.com")
    }

    func testURLMinimizeHost() {
        XCTAssertEqual(URL(string: "http://google.com/search?prout")!.minimizedHost, "google.com")
        XCTAssertEqual(URL(string: "http://www.google.com/search?prout")!.minimizedHost, "google.com")
        XCTAssertEqual(URL(string: "http://search.somedomain.google.com/search?prout")!.minimizedHost, "search.somedomain.google.com")
        XCTAssertEqual(URL(string: "http://google/search?prout")!.minimizedHost, "google")
        XCTAssertNil(URL(string: "google/search?prout")!.minimizedHost)
    }

    func testURLMainHost() {
        XCTAssertEqual(URL(string: "http://google.com/search?prout")!.mainHost, "google.com")
        XCTAssertEqual(URL(string: "http://www.google.com/search?prout")!.mainHost, "google.com")
        XCTAssertEqual(URL(string: "http://search.somedomain.google.com/search?sprout")!.mainHost, "google.com")
        XCTAssertEqual(URL(string: "http://google/search?prout")!.mainHost, "google")
        XCTAssertNil(URL(string: "google/search?prout")!.mainHost)
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

    func testStringToEncodedUrl() {
        let string = "https://www.example.com/上海+中國"
        XCTAssertEqual(string.toEncodedURL?.absoluteString, "https://www.example.com/%E4%B8%8A%E6%B5%B7+%E4%B8%AD%E5%9C%8B")
    }

    func testStringToEncodedUrl_KeepAnchor() {
        let string = "https://www.example.com/#anchor"
        XCTAssertEqual(string.toEncodedURL?.absoluteString, "https://www.example.com/#anchor")
    }

    func testStringToEncodedUrl_KeepAnchorWhenMixedWithEncoding() {
        let string = "https://www.example.com/上海+中國#anchor"
        XCTAssertEqual(string.toEncodedURL?.absoluteString, "https://www.example.com/%E4%B8%8A%E6%B5%B7+%E4%B8%AD%E5%9C%8B#anchor")
    }
}
