import GRDB
import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class FrecencyUrlRecordTests: XCTestCase {
    func testSave() throws {
        let db = GRDBDatabase.empty()

        // Check subsequent record save: primary keys are `urlId` and `frecencyKey`.
        // When a primary key already exists, the record is updated.
        for var rec in [
            FrecencyUrlRecord(urlId: 42, lastAccessAt: Date(timeIntervalSince1970: 0), frecencyScore: 0.34,           frecencySortScore: Float(0), frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: 42, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: 0,              frecencySortScore: Float(0), frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: 42, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: 43, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: 42, lastAccessAt: Date(timeIntervalSince1970: 2), frecencyScore: 1,              frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
        ] {
            try db.saveFrecencyUrl(&rec)
            let frecencyParams = try db.fetchOneFrecency(fromUrl: rec.urlId)

            let frecency = try XCTUnwrap(frecencyParams[rec.frecencyKey])
            expect(frecency.urlId) == rec.urlId
            expect(frecency.lastAccessAt) == rec.lastAccessAt
            expect(frecency.frecencyKey) == rec.frecencyKey
            expect(frecency.frecencyScore) == rec.frecencyScore
        }

        try db.dbReader.read { db in
            try expect(FrecencyUrlRecord.fetchCount(db)) == 3
        }
    }
    func testGetMany() throws {
        let db = GRDBDatabase.empty()
        let records = [
            FrecencyUrlRecord(urlId: 0, lastAccessAt: Date(timeIntervalSince1970: 0), frecencyScore: 0.34,           frecencySortScore: 10, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: 1, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: 0,              frecencySortScore: 9, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: 1, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: 8, frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: 2, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: 7, frecencyKey: .webVisit30d0),
        ]

        for var rec in records {
            try db.saveFrecencyUrl(&rec)
        }
        let scores = try XCTUnwrap( db.getFrecencyScoreValues(urlIds: [0, 1], paramKey: .webVisit30d0))
        XCTAssertEqual(scores.count, 2)
        XCTAssertEqual(scores[0], 10)
        XCTAssertEqual(scores[1], 9)
    }
}
