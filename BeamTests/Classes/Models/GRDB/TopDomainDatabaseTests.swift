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
            TopDomainRecord(url: "google.com"),
            TopDomainRecord(url: "facebook.com"),
            TopDomainRecord(url: "linkedin.com"),
            TopDomainRecord(url: "link.com"),
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

        // Prefix match
        bestHit = try topDomainDatabase.search(withPrefix: "face")
        expect(bestHit?.url) == "facebook.com"

        // Check ranking
        bestHit = try topDomainDatabase.search(withPrefix: "link")
        expect(bestHit?.url) == "linkedin.com"
    }
}
