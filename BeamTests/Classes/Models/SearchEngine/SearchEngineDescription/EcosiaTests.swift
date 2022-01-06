import XCTest
@testable import Beam

class EcosiaTests: XCTestCase {

    private var searchEngine: Ecosia!

    override func setUp() {
        searchEngine = Ecosia()
    }

    func testEcosiaSearchURL() {
        let expected = "https://www.ecosia.org/search?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testEcosiaSuggestionsURL() {
        let expected = "https://ac.ecosia.org/?q=wesh"
        XCTAssertEqual(searchEngine.suggestionsURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testDecodeSuggestions() throws {
        let suggestions = try searchEngine.decodeSuggestions(from: Self.data)

        XCTAssertEqual(suggestions.count, 7)
        guard suggestions.count == 7 else { return }
        XCTAssertEqual(suggestions[0], "steve madden")
        XCTAssertEqual(suggestions[1], "steve jobs")
    }

    private static let data = Data(json.utf8)

    private static var json = """
    {
      "query": "steve",
      "suggestions": [
        "steve madden",
        "steve jobs",
        "steve martin",
        "steve mcqueen",
        "steve quayle",
        "steven seagal",
        "steve harvey"
      ]
    }
    """

}
