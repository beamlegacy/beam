import XCTest
@testable import Beam

class SearchEngineProviderTests: XCTestCase {

    func testGoogleSearchURLs() {
        XCTAssertEqual(SearchEngineProvider.provider(for: URL(string: "https://www.google.com/search?q=steve&client=safari&source=hp")!), .google)
        XCTAssertEqual(SearchEngineProvider.provider(for: URL(string: "https://www.google.com/url?sa=t&rct=j&q=&esrc=s")!), .google)
    }

    func testDuckDuckGoSearchURL() {
        XCTAssertEqual(SearchEngineProvider.provider(for: URL(string: "https://duckduckgo.com/?q=steve&t=h_&ia=web")!), .duckduckgo)
    }

    func testEcosiaSearchURL() {
        XCTAssertEqual(SearchEngineProvider.provider(for: URL(string: "https://www.ecosia.org/search?q=steve")!), .ecosia)
    }

}
