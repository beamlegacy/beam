//
//  BrowserHistoryImportTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 08/12/2021.
//

import XCTest
import Combine
@testable import Beam

class BrowserHistoryImportTest: XCTestCase {

    func testChromeImport() throws {
        let bundle = Bundle(for: type(of: self))
        var subscriptions = Set<AnyCancellable>()
        let historyURL = try XCTUnwrap(bundle.url(forResource: "chromeHistory", withExtension: "db"))
        let importer = ChromiumHistoryImporter(browser: .chrome)
        let expectation = XCTestExpectation(description: "Chrome import finished")
        var results = [BrowserHistoryResult]()
        importer.publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished: expectation.fulfill()
                case .failure(let error): XCTFail("Chrome import failed: \(error)")
                }
            },
            receiveValue: { result in
                results.append(result)
            })
        .store(in: &subscriptions)
        try importer.importHistory(from: historyURL)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(results.count, 3)

        XCTAssertEqual(results[0].item.url.absoluteString, "https://lemonde.fr/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-08 14:14:35 +0000")
        XCTAssertEqual(results[0].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")

        XCTAssertEqual(results[1].item.url.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-08 14:14:35 +0000")
        XCTAssertEqual(results[1].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")

        XCTAssertEqual(results[2].item.url.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[2].item.timestamp.description, "2021-12-08 14:20:36 +0000")
        XCTAssertEqual(results[2].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")
    }
    
    func testSafariImport() throws {
        let bundle = Bundle(for: type(of: self))
        var subscriptions = Set<AnyCancellable>()
        let historyURL = try XCTUnwrap(bundle.url(forResource: "safariHistory", withExtension: "db"))
        let importer = SafariImporter()
        let expectation = XCTestExpectation(description: "Safari import finished")
        var results = [BrowserHistoryResult]()
        importer.publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished: expectation.fulfill()
                case .failure(let error): XCTFail("Safari import failed: \(error)")
                }
            },
            receiveValue: { result in
                results.append(result)
            })
        .store(in: &subscriptions)
        try importer.importHistory(from: historyURL)
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(results[0].item.url.absoluteString, "https://twitter.com/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-09 11:08:22 +0000")
        XCTAssertEqual(results[0].item.title, "")

        XCTAssertEqual(results[1].item.url.absoluteString, "https://twitter.com/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-09 11:08:22 +0000")
        XCTAssertEqual(results[1].item.title, "Twitter. It’s what’s happening / Twitter")
    }

    func testFirefoxImport() throws {
        let bundle = Bundle(for: type(of: self))
        var subscriptions = Set<AnyCancellable>()
        let historyURL = try XCTUnwrap(bundle.url(forResource: "firefoxPlaces", withExtension: "db"))
        let importer = FirefoxImporter()
        let expectation = XCTestExpectation(description: "Firefox import finished")
        var results = [BrowserHistoryResult]()
        importer.publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished: expectation.fulfill()
                case .failure(let error): XCTFail("Firefox import failed: \(error)")
                }
            },
            receiveValue: { result in
                results.append(result)
            })
        .store(in: &subscriptions)
        try importer.importHistory(from: historyURL)
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(results[0].item.url.absoluteString, "http://lemonde.fr/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-09 14:03:29 +0000")
        XCTAssertNil(results[0].item.title)

        XCTAssertEqual(results[1].item.url.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-09 14:03:29 +0000")
        XCTAssertEqual(results[1].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")
    }
}
