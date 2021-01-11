import XCTest
@testable import Beam

class BeamTests: XCTestCase {
    func testMayBeURL() {
        XCTAssertTrue("lemonde.fr".maybeURL)
        XCTAssertFalse("http://lemonde".maybeURL)
        XCTAssertTrue("http://lemonde.fr".maybeURL)
        XCTAssertTrue("http://lemOnde.Fr".maybeURL)
    }
}
