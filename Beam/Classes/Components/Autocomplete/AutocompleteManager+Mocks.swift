//
//  AutocompleteManager+Mocks.swift
//  Beam
//
//  Created by Remi Santos on 30/03/2022.
//

import Foundation
import Combine

#if DEBUG
extension AutocompleteManager {

    private func mockResults(_ results: [AutocompleteResult], source: AutocompleteResult.Source) -> AnyPublisher<AutocompletePublisherSourceResults, Never> {
        Future { promise in
            promise(.success(.init(source: source, results: results)))
        }.eraseToAnyPublisher()
    }

    /// Mocked results publishers; helpful for reproducing issues and debugging
    func getMockAutocompletePublishers(for searchText: String) -> [AnyPublisher<AutocompletePublisherSourceResults, Never>] {
        // this is an exemple, replace with your needs
        // can be useful to return different result depending on the searchText
        return [
            mockResults([
                .init(text: "calendly.com/events", source: .history, url: URL(string: "calendly.com/events")!, completingText: searchText, score: 200)
            ], source: .history),

            mockResults([
                .init(text: "Calendly", source: .note, completingText: searchText, score: 179.2524)
            ], source: .note),

            mockResults([
                .init(text: "Create Note:", source: .createNote, information: searchText, completingText: searchText)
            ], source: .createNote),

            mockResults([
                .init(text: "calendly.com/search", source: .searchEngine, url: URL(string: "calendly.com/search")!, completingText: searchText, score: 187),
                .init(text: "Calendly is cool", source: .searchEngine, completingText: searchText, score: 1.05)
            ], source: .searchEngine)
        ]
    }

}

#endif
