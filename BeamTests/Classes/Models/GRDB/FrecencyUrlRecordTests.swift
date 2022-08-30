import GRDB
import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class FrecencyUrlRecordTests: XCTestCase {
    func testSave() throws {
        let store = GRDBStore(writer: DatabaseQueue())
        let db = try UrlHistoryManager(holder: nil, objectManager: BeamObjectManager(), store: store)
        try store.migrate()

        // Check subsequent record save: primary keys are `urlId` and `frecencyKey`.
        // When a primary key already exists, the record is updated.
        let urlIds = [UUID(), UUID()]
        for rec in [
            FrecencyUrlRecord(urlId: urlIds[0], lastAccessAt: Date(timeIntervalSince1970: 0), frecencyScore: 0.34,           frecencySortScore: Float(0), frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: urlIds[0], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: 0,              frecencySortScore: Float(0), frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: urlIds[0], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: urlIds[1], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: urlIds[0], lastAccessAt: Date(timeIntervalSince1970: 2), frecencyScore: 1,              frecencySortScore: Float(0), frecencyKey: .webReadingTime30d0),
        ] {
            try db.saveFrecencyUrl(rec)
            let frecencyParams = try db.fetchOneFrecency(fromUrl: rec.urlId)

            let frecency = try XCTUnwrap(frecencyParams[rec.frecencyKey])
            expect(frecency.urlId) == rec.urlId
            expect(frecency.lastAccessAt) == rec.lastAccessAt
            expect(frecency.frecencyKey) == rec.frecencyKey
            expect(frecency.frecencyScore) == rec.frecencyScore
        }

        try db.read { db in
            try expect(FrecencyUrlRecord.fetchCount(db)) == 3
        }
    }
    func testFetchNanSortScore() throws {
        let store = GRDBStore(writer: DatabaseQueue())
        let db = try UrlHistoryManager(holder: nil, objectManager: BeamObjectManager(), store: store)
        try store.migrate()

        let id = UUID()
        let record = FrecencyUrlRecord(urlId: id, lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: -1, frecencySortScore: Float.nan, frecencyKey: .webVisit30d0)
        try db.saveFrecencyUrl(record)
        let frecencies = try db.fetchOneFrecency(fromUrl: id)
        let frecency = try XCTUnwrap(frecencies[record.frecencyKey])
        XCTAssertEqual(frecency.frecencySortScore, -Float.greatestFiniteMagnitude)
    }

    func testGetMany() throws {
        let store = GRDBStore(writer: DatabaseQueue())
        let db = try UrlHistoryManager(holder: nil, objectManager: BeamObjectManager(), store: store)
        try store.migrate()

        let urlIds = (0...2).map { _ in UUID() }
        let records = [
            FrecencyUrlRecord(urlId: urlIds[0], lastAccessAt: Date(timeIntervalSince1970: 0), frecencyScore: 0.34,           frecencySortScore: 10, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: urlIds[1], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: 0,              frecencySortScore: 9, frecencyKey: .webVisit30d0),
            FrecencyUrlRecord(urlId: urlIds[1], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: 8, frecencyKey: .webReadingTime30d0),
            FrecencyUrlRecord(urlId: urlIds[2], lastAccessAt: Date(timeIntervalSince1970: 1), frecencyScore: Float.infinity, frecencySortScore: 7, frecencyKey: .webVisit30d0),
        ]

        for rec in records {
            try db.saveFrecencyUrl(rec)
        }
        let scores = try XCTUnwrap( db.getFrecencyScoreValues(urlIds: [urlIds[0], urlIds[1]], paramKey: .webVisit30d0))
        XCTAssertEqual(scores.count, 2)
        XCTAssertEqual(scores[urlIds[0]], 10)
        XCTAssertEqual(scores[urlIds[1]], 9)
    }
}
