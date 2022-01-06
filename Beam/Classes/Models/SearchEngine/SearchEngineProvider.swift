import Foundation

/// A search engine provider, available in user preferences.
enum SearchEngineProvider: String, CaseIterable, Identifiable {

    case google
    case duckduckgo
    case ecosia

    var id: String { rawValue }
    var name: String { searchEngine.name }

    /// Returns a search engine description for the search engine provider.
    var searchEngine: SearchEngineDescription {
        switch self {
        case .google: return GoogleSearch()
        case .duckduckgo: return DuckDuckGo()
        case .ecosia: return Ecosia()
        }
    }

    /// Returns which search engine provider can handle a given query URL, if any.
    static func provider(for queryURL: URL) -> Self? {
        Self.allCases.first(where: { $0.searchEngine.canHandle(queryURL) })
    }

}
