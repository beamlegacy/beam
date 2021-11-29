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

    func testTopFrecenciesMatching() throws {
        let links = [
            Link(url: "http://animal.com/cat", title: nil),
            Link(url: "http://animal.com/dog", title: nil), //is missing frecency
            Link(url: "http://animal.com/cow", title: nil),
            Link(url: "http://animal.com/pig", title: nil),
            Link(url: "http://blabla.fr/", title: nil),
        ]
        let now = BeamDate.now
        let frecencies = [
            FrecencyUrlRecord(urlId: links[0].id, lastAccessAt: now, frecencyScore: 0, frecencySortScore: 5, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: links[0].id, lastAccessAt: now, frecencyScore: 0, frecencySortScore: 2, frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: links[1].id, lastAccessAt: now, frecencyScore: 0, frecencySortScore: 3, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: links[3].id, lastAccessAt: now, frecencyScore: 0, frecencySortScore: 2, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: links[4].id, lastAccessAt: now, frecencyScore: 0, frecencySortScore: 5, frecencyKey: .webVisit30d0),
        ]
        let db = GRDBDatabase.empty()
        try db.insert(links: links)
        for frecency in frecencies {
            try db.saveFrecencyUrl(frecency)
        }
        let results = db.getTopScoredLinks(matchingUrl: "animal", frecencyParam: .webVisit30d0, limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].link.id, links[0].id)
        XCTAssertEqual(results[0].frecency?.frecencySortScore, frecencies[0].frecencySortScore)
        XCTAssertEqual(results[1].link.id, links[1].id)
        XCTAssertEqual(results[1].frecency?.frecencySortScore, frecencies[2].frecencySortScore)
    }
}
