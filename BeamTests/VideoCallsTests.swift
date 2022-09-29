import XCTest
import BeamCore
@testable import Beam

final class VideoCallsTests: XCTestCase {

    func testBasics() throws {
        let manager = VideoCallsManager()

        let url: URL = try XCTUnwrap(URL(string: "https://meet.google.com/nqz-vnxj-xrg"))

        XCTAssertNil(manager.currentPanel)
        try manager.start(with: URLRequest(url: url), faviconProvider: nil)
        XCTAssertNotNil(manager.currentPanel)

        XCTAssertThrowsError(try manager.start(with: URLRequest(url: url), faviconProvider: nil))
    }

    func testURLEligibility() throws {
        let manager = VideoCallsManager()

        XCTAssertTrue(manager.isEligible(url: try XCTUnwrap(URL(string: "https://meet.google.com/nqz-vnxj-xrg"))))
        XCTAssertTrue(manager.isEligible(url: try XCTUnwrap(URL(string: "http://meet.google.com/nqz-vnxj-xrg"))))
        XCTAssertTrue(manager.isEligible(url: try XCTUnwrap(URL(string: "https://beamapp.zoom.us/wc/join/12345678910"))))
        XCTAssertTrue(manager.isEligible(url: try XCTUnwrap(URL(string: "http://beamapp.zoom.us/wc/join/12345678910"))))

        XCTAssertFalse(manager.isEligible(url: try XCTUnwrap(URL(string: "https://calendar.google.com/"))))
        XCTAssertFalse(manager.isEligible(url: try XCTUnwrap(URL(string: "https://www.google.com/search?q=beamapp"))))
        XCTAssertFalse(manager.isEligible(url: try XCTUnwrap(URL(string: "https://zoom.us"))))
        XCTAssertFalse(manager.isEligible(url: try XCTUnwrap(URL(string: "https://facetime.apple.com/join#v=1&p=hDlLUz/TEe2lcgJC+hMtRw&k=YF2Y7sgNhTTrGR8H1_8dhLhhCtmLnPHqbmJTTsgPMpM"))))
    }

}
