import Foundation
import BeamCore

struct Ecosia: SearchEngineDescription {

    let name: String = "Ecosia"
    let description: String = "Ecosia Search"

    var searchHost: String { "www.ecosia.org" }
    var searchPath: String { "/search" }

    var suggestionsHost: String? { "ac.ecosia.org" }

    func decodeSuggestions(from data: Data, encoding: String.Encoding?) throws -> [String] {
        let decoder = BeamJSONDecoder()
        var unicodeData = data
        if let encoding = encoding {
            unicodeData = self.convertDataToUnicodeData(data, currentEncoding: encoding) ?? data
        }
        let response = try decoder.decode(SuggestionsResponse.self, from: unicodeData)
        return response.suggestions
    }

    private struct SuggestionsResponse: Decodable {
        let suggestions: [String]
    }

}
