import XCTest
@testable import Beam

class SearchEngineDescriptionTests: XCTestCase {

    private var searchEngine: SearchEngineDescription!

    override func setUp() {
        searchEngine = MockSearchEngine()
    }

    func testSearchURL() {
        let expected = "https://gigou.tutu/search?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testSuggestionsURL() {
        let expected = "https://suggest.gigou.tutu/turlututu/?q=wesh&glagla=turlututu"
        XCTAssertEqual(searchEngine.suggestionsURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testDecodedSuggestions() throws {
        let data = try JSONSerialization.data(withJSONObject: ["uno", "dos", "tres"])
        XCTAssertEqual(try searchEngine.decodeSuggestions(from: data, encoding: nil), ["uno", "dos", "tres"])
    }

    func testQueryEncoding() {
        let expected = "https://suggest.gigou.tutu/turlututu/?q=wdyt%20about%20c%2B%2B%20%3F%3B%20expensive%3A%3D%24&glagla=turlututu"
        XCTAssertEqual(searchEngine.suggestionsURL(forQuery: "wdyt about c++ ?; expensive:=$")?.absoluteString, expected)
    }

    func testQueryFromURL() {
        guard let url = URL(string: "https://suggest.gigou.tutu/turlututu/?q=wdyt%20about%20c%2B%2B%20%3F%3B%20expensive%3A%3D%24&glagla=turlututu") else {
            fatalError("Couldn't build test URL")
        }
        XCTAssertEqual(searchEngine.queryFromURL(url), "wdyt about c++ ?; expensive:=$")
    }

}

// MARK: -

private struct MockSearchEngine: SearchEngineDescription {

    let name = "Gigou Search"
    let description = "Gigou Search"
    let searchHost = "gigou.tutu"
    let searchPath = "/search"
    let suggestionsHost: String? = "suggest.gigou.tutu"
    let suggestionsPath: String = "/turlututu/"

    func suggestionsQueryItems(for query: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "glagla", value: "turlututu")
        ]
    }

    func decodeSuggestions(from data: Data, encoding: String.Encoding?) throws -> [String] {
        ["uno", "dos", "tres"]
    }

}
