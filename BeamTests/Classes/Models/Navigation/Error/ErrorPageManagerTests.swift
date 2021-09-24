//
//  ErrorPageManagerTests.swift
//  BeamTests
//
//  Created by Florian Mari on 23/09/2021.
//

import XCTest
@testable import Beam

class ErrorPageManagerTests: XCTestCase {

    private func errorBuilder(code: Int) -> NSError {
        NSError(domain: "web", code: code, userInfo: nil)
    }

    func testErrorIsCorrect_WhenRadBlockIsTriggered() {
        let errorPageManager = ErrorPageManager(
            errorBuilder(code: 104),
            webView: .init()
        )
        XCTAssertEqual(errorPageManager.error, .radblock)
    }

    func testErrorIsCorrect_WhenHavingNoNetwork() {
        let errorPageManager = ErrorPageManager(
            errorBuilder(code: NSURLErrorNotConnectedToInternet),
            webView: .init()
        )
        XCTAssertEqual(errorPageManager.error, .network)
    }

    func testErrorIsCorrect_WhenHostIsUnreachable() {
        let errorPageManager = ErrorPageManager(
            errorBuilder(code: NSURLErrorCannotFindHost),
            webView: .init()
        )
        XCTAssertEqual(errorPageManager.error, .hostUnreachable)
    }

    func testErrorIsCorrect_WhenTriggersUnknownError() {
        let errorPageManager = ErrorPageManager(
            errorBuilder(code: 9999999),
            webView: .init()
        )
        XCTAssertEqual(errorPageManager.error, .unknown)
    }
}
