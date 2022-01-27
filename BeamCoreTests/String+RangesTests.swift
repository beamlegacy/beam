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

    func testUTF16NSRange() {

        let text = "some text"
        // whole range
        XCTAssertEqual(text.utf16Range(from: text.startIndex..<text.endIndex), 0..<text.count)
        // range of "text"
        XCTAssertEqual(text.utf16Range(from: text.firstIndex(of: "t")!..<text.endIndex), 5..<text.count)

        let emojiText = "roller 🛼 skate 🛹"
        XCTAssertEqual(emojiText.count + 2, emojiText.utf16.count)
        // whole range
        XCTAssertEqual(emojiText.utf16Range(from: emojiText.startIndex..<emojiText.endIndex), 0..<emojiText.utf16.count)
        // range of "skate 🛹"
        XCTAssertEqual(emojiText.utf16Range(from: emojiText.firstIndex(of: "s")!..<emojiText.endIndex), 10..<emojiText.utf16.count)
    }
}
