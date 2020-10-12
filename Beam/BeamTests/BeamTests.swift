import XCTest
import Fakery
@testable import Beam

class BeamTests: XCTestCase {
    func testSearch() throws {
        let sk = SearchKit()
        sk.append(url: URL(string: "http://test.com/test1")!, contents: String.loremIpsum)
        sk.append(url: URL(string: "http://test.com/test2")!, contents: "Beam is so cool!")

        _ = sk.search("cool")
        let res = sk.search("cool")

        XCTAssert(!res.isEmpty)
    }
}
