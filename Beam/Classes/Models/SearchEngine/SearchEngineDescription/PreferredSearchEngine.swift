import Foundation
import Combine

/// A wrapper that dynamically delegates to the search engine selected in user preferences.
final class PreferredSearchEngine {

    private var searchEngine: SearchEngineDescription
    private var cancellables = Set<AnyCancellable>()

    init() {
        searchEngine = Self.searchEngine(for: PreferencesManager.selectedSearchEngine)

        PreferencesManager.$selectedSearchEngine.sink { [weak self] rawValue in
            self?.updateSearchEngine(rawValue)
        }
        .store(in: &cancellables)
    }

    private func updateSearchEngine(_ rawValue: String) {
        searchEngine = Self.searchEngine(for: rawValue)
    }

    private static func searchEngine(for rawValue: String) -> SearchEngineDescription {
        // Fall back to the default search engine if the `SearchEngineProvider` enumeration does not have a
        // corresponding value.
        let provider = SearchEngineProvider(rawValue: rawValue) ?? PreferencesManager.defaultSearchEngine
        return provider.searchEngine
    }

}

// MARK: - SearchEngineDescription

extension PreferredSearchEngine: SearchEngineDescription {

    var name: String { searchEngine.name }
    var description: String { searchEngine.description }

    var searchHost: String { searchEngine.searchHost }
    var searchPath: String { searchEngine.searchPath }
    var suggestionsHost: String? { searchEngine.suggestionsHost }
    var suggestionsPath: String { searchEngine.suggestionsPath }

    func searchQueryItems(for query: String) -> [URLQueryItem] {
        searchEngine.searchQueryItems(for: query)
    }

    func suggestionsQueryItems(for query: String) -> [URLQueryItem] {
        searchEngine.suggestionsQueryItems(for: query)
    }

    func decodeSuggestions(from data: Data) throws -> [String] {
        try searchEngine.decodeSuggestions(from: data)
    }

    func canHandle(_ queryURL: URL) -> Bool {
        searchEngine.canHandle(queryURL)
    }

}
