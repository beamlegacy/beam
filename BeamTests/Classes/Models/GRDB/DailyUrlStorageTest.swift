//
//  DailyUrlStorageTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 29/03/2022.
//

import XCTest
@testable import BeamCore
@testable import Beam

class DailyUrlStorageTest: XCTestCase {
    var db: UrlStatsDBManager!

    override func setUpWithError() throws {
        let store = GRDBStore.empty()
        db = try UrlStatsDBManager(store: store)
        try store.migrate()
    }

    func testRecord() throws {
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let t0 = BeamDate.now

        let id = UUID()
        let day0 = "2020-01-01"
        let day1 = "2020-01-02"
        //upserting and fetching
        db.updateDailyUrlScore(urlId: id, day: day0) {
            $0.readingTimeToLastEvent += 5
            $0.navigationCountSinceLastSearch = 2
        }
        BeamDate.travel(1)
        let t1 = BeamDate.now
        db.updateDailyUrlScore(urlId: id, day: day0) {
            $0.readingTimeToLastEvent += 5
        }
        db.updateDailyUrlScore(urlId: id, day: day1) {
            $0.scrollRatioY += 0.5
            $0.isPinned = true
        }
        var records0 = db.getDailyUrlScores(day: day0)
        XCTAssertEqual(records0.count, 1)
        var record = try XCTUnwrap(records0[id])
        XCTAssertEqual(record.readingTimeToLastEvent, 10)
        XCTAssertFalse(record.isPinned)
        XCTAssertEqual(record.createdAt, t0)
        XCTAssertEqual(record.updatedAt, t1)
        XCTAssertEqual(record.navigationCountSinceLastSearch, 2)

        var records1 = db.getDailyUrlScores(day: day1)
        XCTAssertEqual(records1.count, 1)
        record = try XCTUnwrap(records1[id])
        XCTAssertEqual(record.scrollRatioY, 0.5)
        XCTAssert(record.isPinned)
        try db.clearDailyUrlScores(toDay: "2020-01-01")
        XCTAssertEqual(record.createdAt, t1)
        XCTAssertEqual(record.updatedAt, t1)
        XCTAssertNil(record.navigationCountSinceLastSearch)

        //clearing records older than 1 day
        records0 = db.getDailyUrlScores(day: day0)
        XCTAssertEqual(records0.count, 0)
        records1 = db.getDailyUrlScores(day: day1)
        XCTAssertEqual(records1.count, 1)

        BeamDate.reset()
    }
    
    func testStorage() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let storage = GRDBDailyUrlScoreStore(db: db, daysToKeep: 1)
        let ids = [UUID(), UUID()]
        storage.apply(to: ids[0]) { $0.scrollRatioY = 0.5 }
        BeamDate.travel(1)
        storage.apply(to: ids[1]) { $0.scrollRatioY = 0.3 }
        BeamDate.travel(36 * 60 * 60)
        storage.apply(to: ids[1]) { $0.scrollRatioY = 0.7 }
        storage.apply(to: ids[0]) { $0.isPinned = true } //filtered out in getHighScoredUrlIds
        storage.apply(to: Link.missing.id) { $0.visitCount = 1 } //filtered out in getHighScoredUrlIds
        
        //scores are sorted by score value
        let scores0 = storage.getHighScoredUrlIds(daysAgo: 1, topN: 2)
        XCTAssertEqual(scores0.count, 2)
        XCTAssertEqual(scores0[0].urlId, ids[0])
        XCTAssertEqual(scores0[0].scrollRatioY, 0.5)
        XCTAssertEqual(scores0[1].urlId, ids[1])
        XCTAssertEqual(scores0[1].scrollRatioY, 0.3)
        //same list but trucated
        let scores1 = storage.getHighScoredUrlIds(daysAgo: 1, topN: 1)
        XCTAssertEqual(scores1.count, 1)
        XCTAssertEqual(scores1[0].urlId, ids[0])

        let scores2 = storage.getHighScoredUrlIds(daysAgo: 0, topN: 2)
        XCTAssertEqual(scores2.count, 1)
        XCTAssertEqual(scores2[0].urlId, ids[1])
        XCTAssertEqual(scores2[0].scrollRatioY, 0.7)

        storage.cleanup()
        XCTAssertEqual(storage.getHighScoredUrlIds(daysAgo: 1).count, 0)
        XCTAssertEqual(storage.getHighScoredUrlIds(daysAgo: 0).count, 1)
        BeamDate.reset()
    }
}
