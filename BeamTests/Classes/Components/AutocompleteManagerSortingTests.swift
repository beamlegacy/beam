//
//  AutocompleteManagerSortingTests.swift
//  BeamTests
//
//  Created by Remi Santos on 03/02/2022.
//

import XCTest

@testable import Beam

class AutocompleteManagerSortingTests: XCTestCase {

    private let manager = AutocompleteManager(searchEngine: MockSearchEngine(), beamState: nil)
    func testAutocompleteResultsUniqueNotes() {

        let noteAId = UUID()
        let notes: [AutocompleteResult] = [
            .init(text: "Note A", source: .note, uuid: noteAId),
            .init(text: "Note B", source: .note, uuid: UUID()),
            .init(text: "Note A diffent title", source: .note, uuid: noteAId),
            .init(text: "Note B", source: .note, uuid: UUID()),
            .init(text: "Note C", source: .note, uuid: UUID()),
        ]
        let result = manager.autocompleteResultsUniqueNotes(sequence: notes)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].uuid, noteAId)
        XCTAssertEqual(result[0].text, "Note A")
        XCTAssertEqual(result[1].text, "Note B")
        XCTAssertEqual(result[2].text, "Note C")
    }

    func testAutocompleteResultsUniqueURLsByPriority() throws {
        guard let urlA = URL(string: "https://beamapp.co/A"),
              let urlB = URL(string: "https://beamapp.co/B")
        else {
            fatalError("Couldn't build URLs")
        }
        // for now, history has priority over urls and top domain
        let urls: [AutocompleteResult] = [
            .init(text: "History B", source: .history, url: urlB),
            .init(text: "URL A", source: .url, url: urlA),
            .init(text: "URL B", source: .topDomain, url: urlB),
            .init(text: "History A", source: .history, url: urlA),
        ]
        let result = manager.autocompleteResultsUniqueURLs(sequence: urls)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "History B")
        XCTAssertEqual(result[1].text, "History A")
    }

    func testAutocompleteResultsUniqueURLsByScore() throws {
        guard let urlA = URL(string: "https://beamapp.co/A"),
              let urlB = URL(string: "https://beamapp.co/B")
        else {
            fatalError("Couldn't build URLs")
        }
        let urls: [AutocompleteResult] = [
            .init(text: "URL B Better Score", source: .url, url: urlB, score: 10),
            .init(text: "URL A", source: .url, url: urlA, score: 9),
            .init(text: "URL B", source: .url, url: urlB, score: nil),
            .init(text: "URL A Better Score", source: .url, url: urlA, score: 10),
        ]
        let result = manager.autocompleteResultsUniqueURLs(sequence: urls)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "URL B Better Score")
        XCTAssertEqual(result[1].text, "URL A Better Score")
    }

    func testAutocompleteResultsUniqueSearchEngine() {
        let engine1 = "Google"
        let engine2 = "Ecosia"
        let notes: [AutocompleteResult] = [
            .init(text: "A", source: .searchEngine, information: engine1, score: 10),
            .init(text: "B", source: .searchEngine, information: engine1, score: nil),
            .init(text: "A", source: .searchEngine, information: engine1, score: 9),
            .init(text: "A", source: .searchEngine, information: engine2, score: 9),
            .init(text: "B", source: .searchEngine, information: engine1, score: 10),
            .init(text: "C", source: .searchEngine, information: engine1, score: nil),
        ]
        let result = manager.autocompleteResultsUniqueSearchEngine(sequence: notes)
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].text, "A")
        XCTAssertEqual(result[0].information, engine1)
        XCTAssertEqual(result[1].text, "A")
        XCTAssertEqual(result[1].information, engine2)
        XCTAssertEqual(result[2].text, "B")
        XCTAssertEqual(result[2].information, engine1)
        XCTAssertEqual(result[3].text, "C")
    }

    func testFilterOutSearchEngineURLResults() {
        guard let urlA = URL(string: "https://beamapp.co/A"),
              let urlB = URL(string: "https://beamapp.co/B")
        else {
            fatalError("Couldn't build URLs")
        }
        let urls: [AutocompleteResult] = [
            .init(text: "URLA", source: .url, url: urlA),
            .init(text: "URLB", source: .url, url: urlB),
            .init(text: "URLC", source: .url)
        ]

        let searchEngineResults: [AutocompleteResult] = [
            .init(text: "URL A", source: .url, url: urlA),
            .init(text: "URL B", source: .url, url: URL(string: "https://beamapp.co/B/Other")),
            .init(text: "Result C", source: .searchEngine)
        ]

        let result = manager.filterOutSearchEngineURLResults(from: searchEngineResults, forURLAlreadyIn: urls)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result, Array(searchEngineResults[1..<3]))
    }

    private let searchEngineResults: [AutocompleteResult] = [
        .init(text: "B1", source: .searchEngine),
        .init(text: "B2", source: .searchEngine),
        .init(text: "B3", source: .searchEngine),
        .init(text: "B4", source: .searchEngine),
        .init(text: "B5", source: .searchEngine),
        .init(text: "B6", source: .searchEngine),
    ]

    func testInsertSearchEngineResults() {

        let base: [AutocompleteResult] = [
            .init(text: "URL1", source: .url),
            .init(text: "B3", source: .searchEngine),
            .init(text: "History1", source: .history),
            .init(text: "History2", source: .history),
        ]

        let result = manager.insertSearchEngineResults(searchEngineResults, in: base)
        let expected = base + searchEngineResults[0..<2] + searchEngineResults[3..<5]
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, expected)
    }

    func testInsertSearchEngineResultsBeforeCreateCard() {
        let base: [AutocompleteResult] = [
            .init(text: "URL1", source: .url),
            .init(text: "B3", source: .searchEngine),
            .init(text: "History1", source: .history),
            .init(text: "New Card", source: .createNote),
        ]

        let result = manager.insertSearchEngineResults(searchEngineResults, in: base)
        let expected = Array(base[0..<3] + searchEngineResults[0..<2] + searchEngineResults[3..<5] + base[3..<4])
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, expected)
    }
}
