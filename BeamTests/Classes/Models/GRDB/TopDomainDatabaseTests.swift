import GRDB
import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class TopDomainDatabaseTests: XCTestCase {
    var topDomainDatabase: TopDomainDatabase!

    override func setUp() {
        topDomainDatabase = try? TopDomainDatabase.empty()
        for var domain in [
            TopDomainRecord(url: "google.com", globalRank: 1),
            TopDomainRecord(url: "facebook.com", globalRank: 42),
            TopDomainRecord(url: "linkedin.com", globalRank: 5),
            TopDomainRecord(url: "link.com", globalRank: 6),
        ] {
            try? topDomainDatabase.dbWriter.write { db in
               try? domain.insert(db)
            }
        }
    }

    override class func tearDown() {
        _ = try? TopDomainDatabase.empty()
    }

    func testSearch() throws {
        // Exact match
        var bestHit = try topDomainDatabase.search(withPrefix: "google.com")
        expect(bestHit?.url) == "google.com"
        expect(bestHit?.globalRank) == 1

        // Prefix match
        bestHit = try topDomainDatabase.search(withPrefix: "face")
        expect(bestHit?.url) == "facebook.com"
        expect(bestHit?.globalRank) == 42

        // Check ranking
        bestHit = try topDomainDatabase.search(withPrefix: "link")
        expect(bestHit?.url) == "linkedin.com"
        expect(bestHit?.globalRank) == 5
    }
}
