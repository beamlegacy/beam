import XCTest
@testable import Beam

class GoogleSearchTests: XCTestCase {

    private var searchEngine: GoogleSearch!

    override func setUp() {
        searchEngine = GoogleSearch()
    }

    func testSearchURL() {
        let expected = "https://www.google.com/search?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testSuggestionsURL() {
        let expected = "https://suggestqueries.google.com/complete/search?q=wesh&client=firefox"
        XCTAssertEqual(searchEngine.suggestionsURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testDecodeSuggestions() throws {
        let data = Data(Self.json.utf8)
        let suggestions = try searchEngine.decodeSuggestions(from: data)

        XCTAssertEqual(suggestions.count, 10)
        guard suggestions.count == 10 else { return }
        XCTAssertEqual(suggestions[0], "steve jobs")
        XCTAssertEqual(suggestions[1], "steve aoki")
    }

    func testCanHandleGoogleSearchURLs() {
        XCTAssertTrue(searchEngine.canHandle(URL(string: "http://google.com/search?proud")!))
        XCTAssertTrue(searchEngine.canHandle(URL(string: "http://google.com/url?proud")!))
        XCTAssertFalse(searchEngine.canHandle(URL(string: "http://groogle.com/search?proud")!))
        XCTAssertFalse(searchEngine.canHandle(URL(string: "http://google.com/blop?proud")!))
    }

    // MARK: -

    private static var json = """
    [
        "steve",
        [
            "steve jobs",
            "steve aoki",
            "steve carell shows",
            "steven alan",
            "steven seagal",
            "steven spielberg",
            "steve carell",
            "steve harvey",
            "steve madden",
            "steve buscemi"
        ],
        [],
        {
            "google: suggestsubtypes": [
                [512],[512],[512],[512],[512],[512],[512],[512],[512],[512]
            ]
        }
    ]
    """

}
