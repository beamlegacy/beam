import Foundation
import XCTest

@testable import Beam
@testable import BeamCore

class BeamLinkDBTests: XCTestCase {
    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()

    override func setUp() {
        super.setUp()
        beforeNetworkTests()
    }

    override func tearDown() {
        super.tearDown()
        stopNetworkTests()
    }
    func testSavingLinkOnBeamObjects() throws {
        let expectation = self.expectation(description: "save link")
        let link = Link(url: "http://abc.com", title: "Your daily dose of alphabet")
        try BeamLinkDB.shared.store(link: link, saveOnNetwork: true) { _ in
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
        do {
            let remoteLink: Link? = try beamObjectHelper.fetchOnAPI(link.beamObjectId)
            XCTAssertNotNil(remoteLink, "Object doesn't exist on the API side?")
            XCTAssertEqual(remoteLink?.id, link.id)
            XCTAssertEqual(remoteLink?.url, link.url)

        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    private func beforeNetworkTests() {
        // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
        // back from Vinyl.
        BeamDate.freeze("2021-03-19T12:21:03Z")

        BeamTestsHelper.logout()

        beamHelper.beginNetworkRecording(test: self)
        BeamTestsHelper.login()
    }

    private func stopNetworkTests() {
        BeamObjectTestsHelper().deleteAll()
        try? BeamLinkDB.shared.deleteAll()
        beamHelper.endNetworkRecording()
    }
}
