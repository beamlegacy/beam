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

    // More Tests TBD https://linear.app/beamapp/issue/BE-3548/more-omnibox-unit-tests

}
