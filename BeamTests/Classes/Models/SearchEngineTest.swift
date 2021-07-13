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
        XCTAssertEqual(googleUrlSearch?.name, SearchEngines.google.name)

        let nonGoogleSearch = SearchEngines.get(URL(string: "http://groogle.com/search?prout")!)
        XCTAssertNil(nonGoogleSearch)

        let nonExistingGoogleSearch = SearchEngines.get(URL(string: "http://google.com/blop?prout")!)
        XCTAssertNil(nonExistingGoogleSearch)
    }

    func testUrlEncoding() {
        let googleSearch = SearchEngines.google
        googleSearch.query = "we like swift"
        XCTAssertEqual(googleSearch.formattedQuery, "we%20like%20swift")
        googleSearch.query = "wdyt about c++ ?; expensive:=$"
        XCTAssertEqual(googleSearch.formattedQuery, "wdyt%20about%20c%2B%2B%20%3F%3B%20expensive%3A%3D%24")
    }
}
