import Foundation
import BeamCore

struct DuckDuckGo: SearchEngineDescription {

    let name: String = "DuckDuckGo"
    let description: String = "DuckDuckGo Search"

    var searchHost: String { "duckduckgo.com" }

    var suggestionsHost: String? { "duckduckgo.com" }
    var suggestionsPath: String { "/ac/" }

    func decodeSuggestions(from data: Data, encoding: String.Encoding?) throws -> [String] {
        let decoder = BeamJSONDecoder()
        var unicodeData = data
        if let encoding = encoding {
            unicodeData = self.convertDataToUnicodeData(data, currentEncoding: encoding) ?? data
        }
        let response = try decoder.decode(SuggestionsResponse.self, from: unicodeData)
        return response.suggestions
    }

    // MARK: -

    private struct SuggestionsResponse: Decodable {

        let suggestions: [String]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let decodedSuggestions = try container.decode([SuggestionResponse].self)
            suggestions = decodedSuggestions.map(\.phrase)
        }

    }

    private struct SuggestionResponse: Decodable {
        let phrase: String
    }

}
