//
//  ErrorPageManagerTests.swift
//  BeamTests
//
//  Created by Florian Mari on 23/09/2021.
//

import XCTest
@testable import Beam

class ErrorPageManagerTests: XCTestCase {

    func testErrorIsCorrect_WhenRadBlockIsTriggered() {
        let errorPageManager = ErrorPageManager(104, webView: .init(), errorUrl: URL(string: "https://google.com")!)
        XCTAssertEqual(errorPageManager.error, .radblock)
    }

    func testErrorIsCorrect_WhenHavingNoNetwork() {
        let errorPageManager = ErrorPageManager(NSURLErrorNotConnectedToInternet, webView: .init(), errorUrl: URL(string: "https://google.com")!)
        XCTAssertEqual(errorPageManager.error, .network)
    }

    func testErrorIsCorrect_WhenHostIsUnreachable() {
        let errorPageManager = ErrorPageManager(NSURLErrorCannotFindHost, webView: .init(), errorUrl: URL(string: "https://google.com")!)
        XCTAssertEqual(errorPageManager.error, .hostUnreachable)
    }

    func testErrorIsCorrect_WhenTriggersUnknownError() {
        let errorPageManager = ErrorPageManager(9999999, webView: .init(), errorUrl: URL(string: "https://google.com")!)
        XCTAssertEqual(errorPageManager.error, .unknown)
    }
}
