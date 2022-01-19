import XCTest
@testable import Beam

class DuckDuckGoTests: XCTestCase {

    private var searchEngine: DuckDuckGo!

    override func setUp() {
        searchEngine = DuckDuckGo()
    }

    func testSearchURL() {
        let expected = "https://duckduckgo.com/?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testSuggestionsURL() {
        let expected = "https://duckduckgo.com/ac/?q=wesh"
        XCTAssertEqual(searchEngine.suggestionsURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testDecodeSuggestions() throws {
        let suggestions = try searchEngine.decodeSuggestions(from: Self.data)

        XCTAssertEqual(suggestions.count, 8)
        guard suggestions.count == 8 else { return }
        XCTAssertEqual(suggestions[0], "steve jobs")
        XCTAssertEqual(suggestions[1], "steven alan")
    }

    private static let data = Data(json.utf8)

    private static var json = """
    [
      {
        "phrase": "steve jobs"
      },
      {
        "phrase": "steven alan"
      },
      {
        "phrase": "steve aoki"
      },
      {
        "phrase": "steven purgatory"
      },
      {
        "phrase": "steve gadd"
      },
      {
        "phrase": "steve jobs speech"
      },
      {
        "phrase": "stevens-johnson症候群"
      },
      {
        "phrase": "steve vai"
      }
    ]
    """

}
