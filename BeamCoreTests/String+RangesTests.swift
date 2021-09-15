//
//  String+RangesTests.swift
//  BeamCoreTests
//
//  Created by Remi Santos on 15/09/2021.
//

import XCTest

class StringRangesTests: XCTestCase {

    func testIndexForCharactersGroups() {
        let text = "some text with some words and a https://link.com nice"

        // before
        XCTAssertEqual(text.indexForCharactersGroup(before: 0), 0)
        XCTAssertEqual(text.indexForCharactersGroup(before: 1), 0) // some
        XCTAssertEqual(text.indexForCharactersGroup(before: 9), 5) // text
        XCTAssertEqual(text.indexForCharactersGroup(before: 11), 10) // with
        XCTAssertEqual(text.indexForCharactersGroup(before: 25), 20) // words
        XCTAssertEqual(text.indexForCharactersGroup(before: 48), 32) // the full link

        // after
        XCTAssertEqual(text.indexForCharactersGroup(after: 0), 4) // some
        XCTAssertEqual(text.indexForCharactersGroup(after: 5), 9) // text
        XCTAssertEqual(text.indexForCharactersGroup(after: 12), 14) // with
        XCTAssertEqual(text.indexForCharactersGroup(after: 20), 25) // words
        XCTAssertEqual(text.indexForCharactersGroup(after: 34), 48) // the full link
        XCTAssertEqual(text.indexForCharactersGroup(after: 53), 53)
    }

}
