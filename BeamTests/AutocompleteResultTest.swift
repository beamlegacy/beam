//
//  AutocompleteResultTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 22/11/2021.
//

import XCTest
@testable import Beam

class AutocompleteResultTest: XCTestCase {

    func testComparison() throws {
        let results = [
            AutocompleteResult(text: "Pierre", source: .autocomplete, score: 1.0),
            AutocompleteResult(text: "Paul", source: .autocomplete, score: 2.0),
            AutocompleteResult(text: "Nicolas", source: .autocomplete, completingText: "Nicol", score: nil),
            AutocompleteResult(text: "Henri", source: .autocomplete, completingText: "Hen", score: nil),
            AutocompleteResult(text: "Louis 16", source: .autocomplete, completingText: "Louis", score: nil),
            AutocompleteResult(text: "Louis 17", source: .autocomplete, completingText: "Louis", score: nil)

        ]
        XCTAssert(results[0] < results[1]) //score value comparison
        XCTAssert(results[2] < results[1]) //non nil score takes precedence of nil one
        XCTAssert(results[1] > results[2]) //non nil score takes precedence of nil one
        XCTAssert(results[3] < results[2]) //fallback on closeness with completing text
        XCTAssert(results[4] < results[5]) //when closeness with completing text is equal: fallback on lexicographical
        XCTAssert(results[5] > results[4]) //when closeness with completing text is equal: fallback on lexicographic

    }
}
