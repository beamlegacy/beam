import XCTest
import BeamCore
@testable import Beam

final class VideoConferencingTests: XCTestCase {

    let url: URL = URL(string: "https://meet.google.com/bla-bla-bla")!

    func testBasics() throws {
        let manager = VideoConferencingManager()

        XCTAssertNil(manager.currentPanel)
        try manager.startVideoConferencing(with: URLRequest(url: url), faviconProvider: nil)
        XCTAssertNotNil(manager.currentPanel)

        XCTAssertThrowsError(try manager.startVideoConferencing(with: URLRequest(url: url), faviconProvider: nil))
    }

}
