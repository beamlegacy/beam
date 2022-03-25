//
//  AutocompleteSortingTests.swift
//  BeamTests
//
//  Created by Remi Santos on 23/03/2022.
//

import XCTest
@testable import Beam

class AutocompleteSortingTests: XCTestCase {

    var sut: AutocompleteManager!

    override func setUp() {
        sut = AutocompleteManager(searchEngine: MockSearchEngine(), beamState: nil)
    }

    private func arLink(_ text: String, info: String? = nil, completing: String? = nil, score: Float? = nil) -> AutocompleteResult {
        .init(text: text, source: .history, information: info, completingText: completing, score: score, urlFields: .text)
    }

    private func arNote(_ text: String, completing: String? = nil, score: Float? = nil) -> AutocompleteResult {
        .init(text: text, source: .note, completingText: completing, score: score)
    }

    // MARK: - Notes merging
    /// Tests that notes scores are easily boosted by the text prefix matching
    func testMergeHistoryAndNotesBoostsNotesMatchingTitle() {
        let searchText = "red"
        let initialResults: [AutocompleteManager.AutocompletePublisherSourceResults] = [
            .init(source: .note, results: [
                arNote("Red Panda", completing: searchText, score: 1.0),
                arNote("Panda", completing: searchText, score: 1.0)
            ]),
            .init(source: .history, results: [
                arLink("redpanda.com", info: "Red pandas are the best", completing: searchText, score: 1.0),
                arLink("redalert.com", info: "the movie red alert", completing: searchText, score: 1.0)
            ])
        ]
        let results = sut.mergeAndSortPublishersResults(publishersResults: initialResults, for: searchText)
        let resultsTitles = results.results.map { $0.text }
        XCTAssertEqual(resultsTitles, ["Red Panda", "redpanda.com", "redalert.com", "Panda"])
    }

    func testMergeHistoryAndNotesDoesntBoostNotesNotMatchingTitle() {
        let searchText = "red"
        let initialResults: [AutocompleteManager.AutocompletePublisherSourceResults] = [
            .init(source: .note, results: [
                arNote("Panda Bear", completing: searchText, score: 1.0),
                arNote("Panda", completing: searchText, score: 1.0)
            ]),
            .init(source: .history, results: [
                arLink("redpanda.com", completing: searchText, score: 1.1),
                arLink("redalert.com", completing: searchText, score: 1.1)
            ])
        ]
        let results = sut.mergeAndSortPublishersResults(publishersResults: initialResults, for: searchText)
        let resultsTitles = results.results.map { $0.text }
        XCTAssertEqual(resultsTitles, ["redpanda.com", "redalert.com", "Panda Bear", "Panda"])
    }

    /// Tests that notes with low scores are not filtered out if their title match
    func testMergeHistoryAndNotesNeverDiscardMatchingNotes() {
        let searchText = "red"
        let initialResults: [AutocompleteManager.AutocompletePublisherSourceResults] = [
            .init(source: .note, results: [
                arNote("Red Panda", completing: searchText, score: 0.8),
                arNote("Panda", completing: searchText, score: 0.8)
            ]),
            .init(source: .history, results: [
                arLink("redpanda.com", completing: searchText, score: 1.5),
                arLink("redgreenblue.com", completing: searchText, score: 1.3),
                arLink("redalert.com", completing: searchText, score: 1.2)
            ])
        ]
        let results = sut.mergeAndSortPublishersResults(publishersResults: initialResults, for: searchText,
                                                                      expectSearchEngineResultsLater: false, limit: 3)
        let resultsTitles = results.results.map { $0.text }

        // "redalert.com" discarded instead of the note "Red Panda"
        // "Panda" discarded because title doesn't match - and not enough space
        XCTAssertEqual(resultsTitles, ["redpanda.com", "redgreenblue.com", "Red Panda"])
    }

    /// Tests that notes with low scores are not filtered out if their title match
    func testMergeHistoryAndNotesAllowDiscardNonMatchingNotes() {
        let searchText = "red"
        let initialResults: [AutocompleteManager.AutocompletePublisherSourceResults] = [
            .init(source: .note, results: [
                arNote("Panda", completing: searchText, score: 1.0)
            ]),
            .init(source: .history, results: [
                arLink("redpanda.com", completing: searchText, score: 1.5),
                arLink("redgreenblue.com", completing: searchText, score: 1.3),
                arLink("redalert.com", completing: searchText, score: 1.2)
            ])
        ]
        let results = sut.mergeAndSortPublishersResults(publishersResults: initialResults, for: searchText,
                                                                      expectSearchEngineResultsLater: false, limit: 3)
        let resultsTitles = results.results.map { $0.text }

        // "Panda" discarded because title doesn't match
        XCTAssertEqual(resultsTitles, ["redpanda.com", "redgreenblue.com", "redalert.com"])
    }

    // MARK: - Deduplication
    func testAutocompleteResultsUniqueNotes() {
        let noteAId = UUID()
        let notes: [AutocompleteResult] = [
            .init(text: "Note A", source: .note, uuid: noteAId),
            .init(text: "Note B", source: .note, uuid: UUID()),
            .init(text: "Note A diffent title", source: .note, uuid: noteAId),
            .init(text: "Note B", source: .note, uuid: UUID()),
            .init(text: "Note C", source: .note, uuid: UUID()),
        ]
        let result = sut.autocompleteResultsUniqueNotes(sequence: notes)
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
        let result = sut.autocompleteResultsUniqueURLs(sequence: urls)
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
            .init(text: "URL A Better Score Longer Text", source: .url, url: urlA, score: 10),
        ]
        let result = sut.autocompleteResultsUniqueURLs(sequence: urls)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].text, "URL B Better Score")
        XCTAssertEqual(result[1].text, "URL A Better Score Longer Text")
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
        let result = sut.autocompleteResultsUniqueSearchEngine(sequence: notes)
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

        let result = sut.filterOutSearchEngineURLResults(from: searchEngineResults, forURLAlreadyIn: urls)
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

        let result = sut.insertSearchEngineResults(searchEngineResults, in: base)
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

        let result = sut.insertSearchEngineResults(searchEngineResults, in: base)
        let expected = Array(base[0..<3] + searchEngineResults[0..<2] + searchEngineResults[3..<5] + base[3..<4])
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, expected)
    }

    // More Tests TBD https://linear.app/beamapp/issue/BE-3548/more-omnibox-unit-tests

}
