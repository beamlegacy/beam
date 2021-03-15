import XCTest
import Nimble

@testable import Beam

class BeamTests: XCTestCase {
    let validURLs = ["lemonde.fr", "http://lemonde.fr", "http://lemOnde.Fr"]
    let invalidURLs = ["http://lemonde"]

    func testMayBeURL() {
        for url in validURLs {
            expect(url.maybeURL) == true
        }

        for url in invalidURLs {
            expect(url.maybeURL) == false
        }
    }
}
