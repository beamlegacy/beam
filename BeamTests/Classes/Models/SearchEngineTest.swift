import XCTest
import Promises
import Nimble

@testable import Beam
@testable import BeamCore

class SearchEngineTest: XCTestCase {

    func testUrlIsSearchResult() {
        let googleSearch = SearchEngines.get(URL(string: "http://google.com/search?prout")!)
        XCTAssertEqual(googleSearch?.name, SearchEngines.google.name)

        let googleUrlSearch = SearchEngines.get(URL(string: "http://google.com/url?prout")!)
        XCTAssertEqual(googleSearch?.name, SearchEngines.google.name)

        let nonGoogleSearch = SearchEngines.get(URL(string: "http://groogle.com/search?prout")!)
        XCTAssertNil(nonGoogleSearch)

        let nonExistingGoogleSearch = SearchEngines.get(URL(string: "http://google.com/blop?prout")!)
        XCTAssertNil(nonExistingGoogleSearch)
    }
}
