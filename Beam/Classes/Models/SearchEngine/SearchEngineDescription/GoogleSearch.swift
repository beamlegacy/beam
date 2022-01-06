import Foundation

struct GoogleSearch: SearchEngineDescription {

    let name: String = "Google"
    let description: String = "Google Search"

    var searchHost: String { "www.google.com" }
    var searchPath: String { "/search" }

    var suggestionsHost: String? { "suggestqueries.google.com" }
    var suggestionsPath: String { "/complete/search" }

    func suggestionsQueryItems(for query: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "client", value: "firefox")
        ]
    }

    func decodeSuggestions(from data: Data) throws -> [String] {
        // Google sends suggestions results with charset ISO-8859-1
        // Convert to ISO Latin first, then convert back to UTF8 data
        let isoString = String(data: data, encoding: .isoLatin1)
        guard let utf8Data = isoString?.data(using: .utf8) else { return [] }

        let response = try JSONSerialization.jsonObject(with: utf8Data)
        guard let array = response as? [Any],
              let suggestions = array[1] as? [String] else {
                  return []
              }

        return suggestions
    }

    func canHandle(_ queryURL: URL) -> Bool {
        guard let host = queryURL.host else { return false }

        return host.hasSuffix("google.com") && (queryURL.path == "/search" || queryURL.path == "/url")
    }

}
