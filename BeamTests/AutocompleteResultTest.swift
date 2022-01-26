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
        XCTAssertLessThan(results[0], results[1]) //score value comparison
        XCTAssertLessThan(results[2], results[1]) //non nil score takes precedence of nil one
        XCTAssertGreaterThan(results[1], results[2]) //non nil score takes precedence of nil one
        XCTAssertLessThan(results[3], results[2]) //fallback on closeness with completing text
        XCTAssertLessThan(results[4], results[5]) //when closeness with completing text is equal: fallback on lexicographical
        XCTAssertGreaterThan(results[5], results[4]) //when closeness with completing text is equal: fallback on lexicographic

    }

    func testNoteScores() {
        let result = AutocompleteResult(text: "note1", source: .note(noteId: nil, elementId: nil), disabled: false, url: nil, information: nil, completingText: "note", uuid: UUID(), score: 1.0, urlFields: [])
        XCTAssertGreaterThan(result.textPrefixScore, 0)
        XCTAssertGreaterThan(result.weightedScore ?? 0, 1)
        XCTAssertGreaterThanOrEqual((result.weightedScore ?? 0), (result.score ?? 0))
        XCTAssertEqual(result.displayText, "note1")
        XCTAssertTrue(result.takeOverCandidate)
    }

    func testURLScores() {
        let result1 = AutocompleteResult(text: "fr.wikipedia.org/Hello_world", source: .url, disabled: false, url: URL(string: "http://fr.wikipedia.org/Hello_world"), information: "Hello world", completingText: "hel", uuid: UUID(), score: 1.0, urlFields: [.text])
        XCTAssertEqual(result1.textPrefixScore, 0)
        XCTAssertGreaterThan(result1.weightedScore ?? 0, 1)
        XCTAssertGreaterThanOrEqual((result1.weightedScore ?? 0), (result1.score ?? 0))
        XCTAssertEqual(result1.displayText, "Hello world")
        XCTAssertTrue(result1.takeOverCandidate)

        let result2 = AutocompleteResult(text: "Hello world", source: .url, disabled: false, url: URL(string: "http://fr.wikipedia.org/Hello_world"), information: "fr.wikipedia.org/Hello_world", completingText: "hel", uuid: UUID(), score: 1.0, urlFields: [.info])
        XCTAssertGreaterThan(result2.textPrefixScore, 0)
        XCTAssertGreaterThan(result2.weightedScore ?? 0, 1)
        XCTAssertGreaterThanOrEqual((result2.weightedScore ?? 0), (result2.score ?? 0))
        XCTAssertEqual(result2.displayText, "Hello world")
        XCTAssertTrue(result2.takeOverCandidate)
    }

    func testURLOverTitle() {
        let result1 = AutocompleteResult(text: "lemonde.fr/proud", source: .url, disabled: false, url: URL(string: "http://lemonde.fr/proud"), information: "Le Monde.fr", completingText: "le", uuid: UUID(), score: 1.0, urlFields: [.text])
        XCTAssertGreaterThan(result1.textPrefixScore, result1.infoPrefixScore)
        XCTAssertGreaterThanOrEqual(result1.rawTextPrefixScore, result1.rawInfoPrefixScore)
        XCTAssertEqual(result1.displayText, "lemonde.fr/proud")
        XCTAssertTrue(result1.takeOverCandidate)
    }

    func testURLMatchInTheMiddle() {
        let result1 = AutocompleteResult(text: "Hello world", source: .url, disabled: false, url: URL(string: "http://fr.wikipedia.org/Hello_world"), information: "fr.wikipedia.org/Hello_world", completingText: "wor", uuid: UUID(), score: 1.0, urlFields: [.info])
        XCTAssertEqual(result1.displayInformation, "fr.wikipedia.org/Hello_world")
        XCTAssertEqual(result1.displayText, "world")
        XCTAssertTrue(result1.takeOverCandidate)

        let result2 = AutocompleteResult(text: "fr.wikipedia.org/Hello_world", source: .url, disabled: false, url: URL(string: "http://fr.wikipedia.org/Hello_world"), information: "Hello world", completingText: "hel", uuid: UUID(), score: 1.0, urlFields: [.text])
        XCTAssertEqual(result2.displayInformation, "fr.wikipedia.org/Hello_world")
        XCTAssertEqual(result2.displayText, "Hello world")
        XCTAssertTrue(result2.takeOverCandidate)
    }

    func testCreateNoteMatchInTheMiddle() {
        let result = AutocompleteResult(text: "Hello world", source: .createCard, disabled: false, url: nil, information: nil, completingText: "wor", uuid: UUID(), score: 1.0, urlFields: [])
        // Check that the matcher doesn't cut the test to "world"
        XCTAssertEqual(result.displayText, "Hello world")
        XCTAssertNil(result.displayInformation)
        XCTAssertFalse(result.takeOverCandidate)
    }

    func testNoteMatchInTheMiddle() {
        let result = AutocompleteResult(text: "Hello world", source: .note(noteId: nil, elementId: nil), disabled: false, url: nil, information: nil, completingText: "wor", uuid: UUID(), score: 1.0, urlFields: [])
        // Check that the matcher doesn't cut the test to "world"
        XCTAssertEqual(result.displayText, "Hello world")
        XCTAssertNil(result.displayInformation)
        XCTAssertFalse(result.takeOverCandidate)
    }
}
