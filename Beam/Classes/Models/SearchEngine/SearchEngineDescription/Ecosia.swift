import Foundation

struct Ecosia: SearchEngineDescription {

    let name: String = "Ecosia"
    let description: String = "Ecosia Search"

    var searchHost: String { "www.ecosia.org" }
    var searchPath: String { "/search" }

    var suggestionsHost: String? { "ac.ecosia.org" }

    func decodeSuggestions(from data: Data) throws -> [String] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(SuggestionsResponse.self, from: data)
        return response.suggestions
    }

    private struct SuggestionsResponse: Decodable {
        let suggestions: [String]
    }

}
