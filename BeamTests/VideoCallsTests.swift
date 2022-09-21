import XCTest
import BeamCore
@testable import Beam

final class VideoCallsTests: XCTestCase {

    let url: URL = URL(string: "https://meet.google.com/bla-bla-bla")!

    func testBasics() throws {
        let manager = VideoCallsManager()

        XCTAssertNil(manager.currentPanel)
        try manager.start(with: URLRequest(url: url), faviconProvider: nil)
        XCTAssertNotNil(manager.currentPanel)

        XCTAssertThrowsError(try manager.start(with: URLRequest(url: url), faviconProvider: nil))
    }

}
