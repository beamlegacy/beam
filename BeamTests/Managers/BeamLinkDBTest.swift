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
        try? BeamLinkDB.shared.deleteAll()
        stopNetworkTests()
    }
    func testSavingLinkOnBeamObjects() throws {
        beforeNetworkTests()
        let expectation = self.expectation(description: "save link")
        let link = Link(url: "http://abc.com", title: "Your daily dose of alphabet")
        try BeamLinkDB.shared.store(link: link, shouldSaveOnNetwork: true) { _ in
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

    func testDomain() throws {
        //not a domain case
        let url0 = "http://123.fr/yourdestiny.html"
        let id0 = BeamLinkDB.shared.createIdFor(url: url0)
        var isDomain = try XCTUnwrap(BeamLinkDB.shared.isDomain(id: id0))
        XCTAssertFalse(isDomain)
        var expectation = self.expectation(description: "save first link")
        var domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id0) { _ in expectation.fulfill()})
        wait(for: [expectation], timeout: 10.0)
        var domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://123.fr/")

        //domain case
        let url1 = "http://depannage.com"
        let id1 = BeamLinkDB.shared.createIdFor(url: url1)
        isDomain = try XCTUnwrap(BeamLinkDB.shared.isDomain(id: id1))
        XCTAssert(isDomain)
        var apiCallCountBefore = APIRequest.networkCallFiles.count
        expectation = self.expectation(description: "save second link")
        domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id1) { _ in expectation.fulfill()} )
        wait(for: [expectation], timeout: 10.0)
        var apiCallCountAfter = APIRequest.networkCallFiles.count

        //first time a domain id is inserted in db, a network call is made
        XCTAssertEqual(apiCallCountBefore + 1, apiCallCountAfter)
        domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://depannage.com/")

        //no additional newtwork call when getting same domain id
        apiCallCountBefore = APIRequest.networkCallFiles.count
        _ = BeamLinkDB.shared.getDomainId(id: id1)
        apiCallCountAfter = APIRequest.networkCallFiles.count
        XCTAssertEqual(apiCallCountBefore, apiCallCountAfter)

        //no existing id case
        XCTAssertNil(BeamLinkDB.shared.isDomain(id: UUID()))
        XCTAssertNil(BeamLinkDB.shared.getDomainId(id: UUID()))
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
        beamHelper.endNetworkRecording()
    }
}
