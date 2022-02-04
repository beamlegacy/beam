import Foundation
import BeamCore

/// A protocol describing a search engine provider, notably where to fetch its search results and suggestions.
protocol SearchEngineDescription {

    var name: String { get }
    var description: String { get }

    var searchHost: String { get }
    var searchPath: String { get }

    var suggestionsHost: String? { get }
    var suggestionsPath: String { get }

    func searchQueryItems(for query: String) -> [URLQueryItem]
    func suggestionsQueryItems(for query: String) -> [URLQueryItem]
    func queryFromURL(_ url: URL) -> String?

    /// Decodes the suggestions from the response returned by a search engine provider.
    func decodeSuggestions(from data: Data) throws -> [String]

    func canHandle(_ queryURL: URL) -> Bool

}

extension SearchEngineDescription {

    var searchPath: String { "/" }
    var suggestionsHost: String? { nil }
    var suggestionsPath: String { "/" }

    func searchQueryItems(for query: String) -> [URLQueryItem] {
        [URLQueryItem(name: "q", value: query)]
    }

    func suggestionsQueryItems(for query: String) -> [URLQueryItem] {
        [URLQueryItem(name: "q", value: query)]
    }

    func queryFromURL(_ url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItem = components.queryItems?.first(where: { $0.name == "q" }) else {
                  return nil
              }
        return queryItem.value
    }

    func decodeSuggestions(from data: Data) throws -> [String] { [] }

    func canHandle(_ queryURL: URL) -> Bool {
        queryURL.host == searchHost && queryURL.path == searchPath
    }

}

extension SearchEngineDescription {

    func searchURL(forQuery query: String) -> URL? {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = searchHost
        urlComponents.path = searchPath
        urlComponents.percentEncodedQueryItems = searchQueryItems(for: Self.formatQuery(query))
        return urlComponents.url
    }

    func suggestionsURL(forQuery query: String) -> URL? {
        guard let host = suggestionsHost else {
            // No suggestions service available for this search engine
            return nil
        }

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = host
        urlComponents.path = suggestionsPath
        urlComponents.percentEncodedQueryItems = suggestionsQueryItems(for: Self.formatQuery(query))
        return urlComponents.url
    }

    func suggestions(from data: Data) -> [String] {
        do {
            return try decodeSuggestions(from: data)

        } catch let DecodingError.dataCorrupted(errorContext),
                let DecodingError.keyNotFound(_, errorContext),
                let DecodingError.typeMismatch(_, errorContext),
                let DecodingError.valueNotFound(_, errorContext) {
            Logger.shared.logError("Failed decoding suggestions: \(errorContext.debugDescription) – \(errorContext.codingPath)", category: .search)

        } catch {
            Logger.shared.logError("Failed decoding suggestions: \(error.localizedDescription)", category: .search)
        }
        return []
    }

    private static func formatQuery(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: .urlSearchQueryAllowed) ?? query
    }

}

// MARK: -

private extension CharacterSet {

    static var urlSearchQueryAllowed: CharacterSet {
        var allowedQueryParamAndKey = CharacterSet.urlQueryAllowed
        allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
        return allowedQueryParamAndKey
    }

}
