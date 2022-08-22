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
    var urlStatsDb: UrlStatsDBManager!
    var urlHistoryDb: UrlHistoryManager!

    override func setUpWithError() throws {
        let store = GRDBStore.empty()
        urlStatsDb = try UrlStatsDBManager(store: store)
        urlHistoryDb = try UrlHistoryManager(store: store)
        try store.migrate()
    }

    func testRecord() throws {
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let t0 = BeamDate.now

        let id = UUID()
        let day0 = "2020-01-01"
        let day1 = "2020-01-02"
        //upserting and fetching
        urlStatsDb.updateDailyUrlScore(urlId: id, day: day0) {
            $0.readingTimeToLastEvent += 5
            $0.navigationCountSinceLastSearch = 2
        }
        BeamDate.travel(1)
        let t1 = BeamDate.now
        urlStatsDb.updateDailyUrlScore(urlId: id, day: day0) {
            $0.readingTimeToLastEvent += 5
        }
        urlStatsDb.updateDailyUrlScore(urlId: id, day: day1) {
            $0.scrollRatioY += 0.5
            $0.isPinned = true
        }
        var records0 = urlStatsDb.getDailyUrlScores(day: day0)
        XCTAssertEqual(records0.count, 1)
        var record = try XCTUnwrap(records0[id])
        XCTAssertEqual(record.readingTimeToLastEvent, 10)
        XCTAssertFalse(record.isPinned)
        XCTAssertEqual(record.createdAt, t0)
        XCTAssertEqual(record.updatedAt, t1)
        XCTAssertEqual(record.navigationCountSinceLastSearch, 2)

        var records1 = urlStatsDb.getDailyUrlScores(day: day1)
        XCTAssertEqual(records1.count, 1)
        record = try XCTUnwrap(records1[id])
        XCTAssertEqual(record.scrollRatioY, 0.5)
        XCTAssert(record.isPinned)
        try urlStatsDb.clearDailyUrlScores(toDay: "2020-01-01")
        XCTAssertEqual(record.createdAt, t1)
        XCTAssertEqual(record.updatedAt, t1)
        XCTAssertNil(record.navigationCountSinceLastSearch)

        //clearing records older than 1 day
        records0 = urlStatsDb.getDailyUrlScores(day: day0)
        XCTAssertEqual(records0.count, 0)
        records1 = urlStatsDb.getDailyUrlScores(day: day1)
        XCTAssertEqual(records1.count, 1)

        BeamDate.reset()
    }
    
    func testStorage() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let storage = GRDBDailyUrlScoreStore(db: urlStatsDb, daysToKeep: 1)
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
    
    func testGetRepeatingUrls() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let urls = [
            "http://colors.com/#red",
            "http://colors.com/#blue",
            "http://here.com/",
            "http://here.com/#or_there"
        ]
        let linkStore = LinkStore(linkManager: BeamLinkDB(overridenManager: urlHistoryDb))
        let storage = GRDBDailyUrlScoreStore(db: urlStatsDb, daysToKeep: 1)
        let urlIds = urls.map { linkStore.getOrCreateId(for: $0) }
        
        storage.apply(to: urlIds[2]) { $0.visitCount = 1 }  //out of time bounds, not taken into account

        BeamDate.travel(10 * 24 * 60 * 60)
        storage.apply(to: urlIds[0]) { $0.visitCount = 1 }
        storage.apply(to: urlIds[2]) { $0.visitCount = 1 }
        storage.apply(to: urlIds[3]) { $0.visitCount = 1 }


        BeamDate.travel(24 * 60 * 60)
        storage.apply(to: urlIds[1]) { $0.visitCount = 1 }

        let repeating = storage.getDailyRepeatingUrlsWithoutFragment(between: 5, and: 0, minRepeat: 2)
        XCTAssertEqual(repeating, Set(["http://colors.com/"]))
        BeamDate.reset()
    }
    func testGetRepeatingUrlsSpeed() throws {
        let linkStore = LinkStore(linkManager: BeamLinkDB(overridenManager: urlHistoryDb))

        for siteIndex in 0...99 {
            for fragmentIndex in 0...99 {
                let urlId = linkStore.getOrCreateId(for: "http://site\(siteIndex).com/#fragment\(fragmentIndex)")
                for day in 1...7 {
                    urlStatsDb.updateDailyUrlScore(urlId: urlId, day: "2022-01-0\(day)") { $0.visitCount = 1}
                }
            }
        }

        measure {
            let repeated = try? urlStatsDb.getDailyRepeatingUrlsWithoutFragment(between: "2022-01-01", and: "2022-01-07", minRepeat: 1)
            XCTAssertEqual(repeated?.count, 100)
        }
    }

    func testGetRepeatingUrlsInScorer() throws {
        let urls = [
            "http://colors.fr/red", //url will be visited 2 distinct days
            "http://fruits.org/orange"
        ]

        let params = DailySummaryUrlParams(minReadingTime: 0, minTextAmount: 0, maxRepeatTimeFrame: 5, maxRepeat: 2)
        let linkStore = LinkStore(linkManager: BeamLinkDB(overridenManager: urlHistoryDb))
        let urlIds = urls.map { linkStore.getOrCreateId(for: $0) }
        let store = GRDBDailyUrlScoreStore(db: urlStatsDb, daysToKeep: 10)
        let scorer = DailyUrlScorer(store: store, params: params, linkStore: linkStore)

        BeamDate.freeze("2001-01-01T00:00:00+000")
        store.apply(to: urlIds[0]) { $0.visitCount = 1 }

        BeamDate.travel(2 * 24 * 60 * 60)
        store.apply(to: urlIds[0]) {
            $0.visitCount = 1
            $0.readingTimeToLastEvent = 100
        }
        store.apply(to: urlIds[1]) {
            $0.visitCount = 1
            $0.readingTimeToLastEvent = 5
        }

        BeamDate.travel(2 * 24 * 60 * 60)
        let scores = scorer.getHighScoredUrls(between: 2, and: 2, topN: 1, filtered: true)
        XCTAssertEqual(scores.count, 1)
        XCTAssertEqual(scores[0].url.absoluteString, urls[1])
        BeamDate.reset()
    }

    func testGetAggregated() throws {
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let store = GRDBDailyUrlScoreStore(db: urlStatsDb, daysToKeep: 10)
        let urlIds = [UUID(), UUID()]
        store.apply(to: urlIds[0]) {
            $0.textSelections = 3 // out of time frame
        }
        BeamDate.travel(24 * 60 * 60)
        store.apply(to: urlIds[0]) {
            $0.textSelections = 1
        }
        BeamDate.travel(24 * 60 * 60)
        store.apply(to: urlIds[1]) {
            $0.visitCount = 1
            $0.readingTimeToLastEvent = 1
            $0.textSelections = 1
            $0.scrollRatioX = 0.5
            $0.scrollRatioY = 0.4
            $0.textAmount = 10
            $0.area = 13
            $0.isPinned = false
            $0.navigationCountSinceLastSearch = 3
        }
        BeamDate.travel(24 * 60 * 60)
        store.apply(to: urlIds[1]) {
            $0.visitCount = 3
            $0.readingTimeToLastEvent = 0
            $0.textSelections = 7
            $0.scrollRatioX = 0.4
            $0.scrollRatioY = 0.8
            $0.textAmount = 12
            $0.area = 10
            $0.isPinned = true
            $0.navigationCountSinceLastSearch = 2
        }
        BeamDate.travel(24 * 60 * 60)
        store.apply(to: urlIds[0]) {
            $0.textSelections = 3 // out of timeframe
        }
        let scores = store.getAggregatedScores(between: 3, and: 1)
        let score0 = try XCTUnwrap(scores[urlIds[0]])
        XCTAssertEqual(score0.visitCount, 0)
        XCTAssertEqual(score0.readingTimeToLastEvent, 0)
        XCTAssertEqual(score0.textSelections, 1)
        XCTAssertEqual(score0.scrollRatioX, 0)
        XCTAssertEqual(score0.scrollRatioY, 0)
        XCTAssertEqual(score0.textAmount, 0)
        XCTAssertEqual(score0.area, 0)
        XCTAssertEqual(score0.isPinned, false)
        XCTAssertNil(score0.navigationCountSinceLastSearch)

        let score1 = try XCTUnwrap(scores[urlIds[1]])
        XCTAssertEqual(score1.visitCount, 4)
        XCTAssertEqual(score1.readingTimeToLastEvent, 1)
        XCTAssertEqual(score1.textSelections, 8)
        XCTAssertEqual(score1.scrollRatioX, 0.5)
        XCTAssertEqual(score1.scrollRatioY, 0.8)
        XCTAssertEqual(score1.textAmount, 12)
        XCTAssertEqual(score1.area, 13)
        XCTAssertEqual(score1.isPinned, true)
        XCTAssertEqual(score1.navigationCountSinceLastSearch, 2)

        BeamDate.reset()
    }
}
