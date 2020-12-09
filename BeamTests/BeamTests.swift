import XCTest
@testable import Beam

class BeamTests: XCTestCase {
    func testSearch() throws {
        let searchKit = SearchKit()

        searchKit.append(url: URL(string: "http://test.com/test1")!, contents: String.loremIpsum)
        searchKit.append(url: URL(string: "http://test.com/test2")!, contents: "Beam is so cool!")

        // To avoid a bug
        _ = searchKit.search("cool")
        let res = searchKit.search("cool")

        XCTAssert(!res.isEmpty)
    }

    func testMayBeURL() {
        XCTAssertTrue("lemonde.fr".maybeURL)
        XCTAssertFalse("http://lemonde".maybeURL)
        XCTAssertTrue("http://lemonde.fr".maybeURL)
        XCTAssertTrue("http://lemOnde.Fr".maybeURL)
    }
}
