import Foundation
import XCTest

@testable import Beam
@testable import BeamCore

class BeamLinkDBTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        try? BeamLinkDB.shared.deleteAll()
    }

    func testDomain() throws {
        //not a domain case
        let url0 = "http://123.fr/yourdestiny.html"
        let id0 = BeamLinkDB.shared.getOrCreateIdFor(url: url0, title: nil)
        var isDomain = BeamLinkDB.shared.isDomain(id: id0)
        XCTAssertFalse(isDomain)
        var domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id0))
        var domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://123.fr/")

        //domain case
        let url1 = "http://depannage.com"
        let id1 = BeamLinkDB.shared.getOrCreateIdFor(url: url1, title: nil)
        isDomain = BeamLinkDB.shared.isDomain(id: id1)
        XCTAssert(isDomain)
        domainId = try XCTUnwrap(BeamLinkDB.shared.getDomainId(id: id1))
        domainLink = try XCTUnwrap(BeamLinkDB.shared.linkFor(id: domainId))
        XCTAssertEqual(domainLink.url, "http://depannage.com/")

        //no existing id case
        XCTAssertFalse(BeamLinkDB.shared.isDomain(id: UUID()))
        XCTAssertNil(BeamLinkDB.shared.getDomainId(id: UUID()))
    }
}
