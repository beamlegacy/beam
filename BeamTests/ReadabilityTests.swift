//
//  ReadabilityTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 11/08/2022.
//

import XCTest
import Nimble
@testable import BeamCore
@testable import Beam

class ReadabilityTests: WebBrowsingBaseTests {

    func testTitleExtraction() throws {
        let titleUrl = "http://lvh.me:\(Configuration.MockHttpServer.port)/readability/title"

        let indexExpectation = expectation(description: "index")
        mockIndexingDelegate?.onIndexingFinished = { _ in
            indexExpectation.fulfill()
        }
        tab.load(request: URLRequest(url: URL(string: titleUrl)!))
        wait(for: [indexExpectation], timeout: 1)
        XCTAssertEqual(tab.browsingTree.current.title, "html title")
    }
}
