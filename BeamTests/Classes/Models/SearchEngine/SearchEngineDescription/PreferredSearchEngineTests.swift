import XCTest
@testable import Beam

class PreferredSearchEngineTests: XCTestCase {

    private var searchEngine: PreferredSearchEngine!

    override func setUp() {
        searchEngine = PreferredSearchEngine()
    }

    override func tearDown() {
        PreferencesManager.selectedSearchEngine = PreferencesManager.defaultSearchEngine.rawValue
    }

    func testDuckDuckGoSearchURL() {
        PreferencesManager.selectedSearchEngine = SearchEngineProvider.duckduckgo.rawValue

        let expected = "https://duckduckgo.com/?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testEcosiaSearchURL() {
        PreferencesManager.selectedSearchEngine = SearchEngineProvider.ecosia.rawValue

        let expected = "https://www.ecosia.org/search?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

    func testSelectedSearchEngineUnavailable() {
        PreferencesManager.selectedSearchEngine = "whatevs"

        let expected = "https://www.google.com/search?q=wesh"
        XCTAssertEqual(searchEngine.searchURL(forQuery: "wesh")?.absoluteString, expected)
    }

}
