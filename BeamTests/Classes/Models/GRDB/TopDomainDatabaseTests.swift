import GRDB
import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class TopDomainDatabaseTests: XCTestCase {
    func testSearch() throws {
        let db = try TopDomainDatabase.empty()

        for var domain in [
            TopDomainRecord(url: "google.com", globalRank: 1),
            TopDomainRecord(url: "facebook.com", globalRank: 42),
            TopDomainRecord(url: "linkedin.com", globalRank: 5),
            TopDomainRecord(url: "link.com", globalRank: 6),
        ] {
            try db.insert(topDomain: &domain)
        }

        // Exact match
        var bestHit = try db.search(withPrefix: "google.com")
        expect(bestHit?.url) == "google.com"
        expect(bestHit?.globalRank) == 1

        // Prefix match
        bestHit = try db.search(withPrefix: "face")
        expect(bestHit?.url) == "facebook.com"
        expect(bestHit?.globalRank) == 42

        // Check ranking
        bestHit = try db.search(withPrefix: "link")
        expect(bestHit?.url) == "linkedin.com"
        expect(bestHit?.globalRank) == 5
    }
}
