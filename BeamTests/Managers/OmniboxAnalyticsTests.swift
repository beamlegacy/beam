//
//  OmniboxAnalyticsTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 23/05/2022.
//

import XCTest
import Nimble
@testable import BeamCore
@testable import Beam

class OmniboxAnalyticsTests: XCTestCase {
    var state: BeamState!
    var analyticsBackend: InMemoryAnalyticsBackend!

    override func setUpWithError() throws {
        AppDelegate.main.deleteAllLocalData()
        BeamObjectManager.disableSendingObjects = true
        state = BeamState()
        state.data = BeamData()
        analyticsBackend = InMemoryAnalyticsBackend()
        state.data.analyticsCollector.add(backend: analyticsBackend)
    }

    override func tearDownWithError() throws {
        analyticsBackend.events = []
        state.data.analyticsCollector.removeBackend(type: .inMemory)
        AppDelegate.main.deleteAllLocalData()
    }

    func testAbortedQuery() throws {
        state.startFocusOmnibox()
        state.stopFocusOmnibox()
        let lastEvent = try XCTUnwrap(analyticsBackend.events.last as? OmniboxQueryAnalyticsEvent)
        XCTAssertEqual(lastEvent.type, .omniboxQuery)
        XCTAssertEqual(lastEvent.resultCount, 0)
        XCTAssertEqual(lastEvent.queryLength, 0)
        XCTAssertEqual(lastEvent.chosenItemPosition, nil)
        XCTAssertEqual(lastEvent.exitState, .aborted)
    }

    private func queryAndTestOmnibox(_ query: String, selectedIndex: Int?, expectedExitState: OmniboxExitState,
                                     autocompleteResults: AutocompleteManager.AutocompletePublisherSourceResults) throws {
        state.startFocusOmnibox(autocompleteMode: .test(results: autocompleteResults))
        state.autocompleteManager.searchQuery = query
        _ = state.autocompleteManager.replacementTextForProposedText(query) //feeds the actual typed query in autocompleteManager
        expect(self.state.autocompleteManager.autocompleteResults.count).toEventually(equal(autocompleteResults.results.count))
        state.autocompleteManager.autocompleteSelectedIndex = selectedIndex
        state.startOmniboxQuery(navigate: false) //runs method without actually navigating to destination url

        let lastEvent = try XCTUnwrap(analyticsBackend.events.last as? OmniboxQueryAnalyticsEvent)
        XCTAssertEqual(lastEvent.type, .omniboxQuery)
        XCTAssertEqual(lastEvent.resultCount, autocompleteResults.results.count)
        XCTAssertEqual(lastEvent.queryLength, query.count)
        XCTAssertEqual(lastEvent.chosenItemPosition, selectedIndex)
        XCTAssertEqual(lastEvent.exitState, expectedExitState)
    }

    func testChosenAutocomplete() throws {
        let results = AutocompleteManager.AutocompletePublisherSourceResults(
            id: UUID(),
            source: .searchEngine,
            results: [AutocompleteResult(text: "abc", source: .searchEngine), AutocompleteResult(text: "def", source: .searchEngine)]
        )
        try queryAndTestOmnibox("lem", selectedIndex: 1, expectedExitState: .autocompleteResult(source: .searchEngine), autocompleteResults: results)
    }

    func testRawQueryUrl() throws {
        let results = AutocompleteManager.AutocompletePublisherSourceResults(
            id: UUID(),
            source: .searchEngine,
            results: []
        )
        try queryAndTestOmnibox("http://www.lemonde.fr/", selectedIndex: nil, expectedExitState: .url, autocompleteResults: results)
    }

    func testRawQuerySearch() throws {
        let results = AutocompleteManager.AutocompletePublisherSourceResults(
            id: UUID(),
            source: .searchEngine,
            results: []
        )
        try queryAndTestOmnibox("a walk in the park", selectedIndex: nil, expectedExitState: .searchQuery, autocompleteResults: results)
    }
}
