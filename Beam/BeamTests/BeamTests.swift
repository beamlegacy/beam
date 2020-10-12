import XCTest
import Fakery
@testable import Beam

class BeamTests: XCTestCase {
    func testSearch() throws {
        let searchKit = SearchKit()
        let faker = Faker()

        searchKit.append(url: URL(string: "http://test.com/test1")!, contents: faker.lorem.paragraph())
        searchKit.append(url: URL(string: "http://test.com/test2")!, contents: "Beam is so cool!")

        // To avoid a bug
        _ = searchKit.search("cool")
        let res = searchKit.search("cool")

        XCTAssert(!res.isEmpty)
    }
}
