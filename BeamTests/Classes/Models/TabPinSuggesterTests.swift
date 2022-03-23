//
//  PinTabSuggesterTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 08/03/2022.
//


import Foundation
import BeamCore
@testable import Beam
import XCTest

class TabPinSuggesterTests: XCTestCase {
    var existingHasPinned: Bool!
    override func setUp() {
        super.setUp()
        existingHasPinned = Persistence.TabPinSuggestion.hasPinned
    }

    override func tearDown() {
        Persistence.TabPinSuggestion.hasPinned = existingHasPinned
        super.tearDown()
    }

    func testCandidateQuery() throws {
        BeamDate.freeze("2001-01-01T15:00:00+000")
        let db = GRDBDatabase.empty()
        let treeIds = [UUID(), UUID()]
        let urls = [
            "https://site.a/path",
        ]
        //not enough observed days, tree share of readtime to low and tree average life time too low
        try db.addDomainPath0ReadingDay(domainPath0: urls[0], date: BeamDate.now)
        try db.updateDomainPath0TreeStat(domainPath0: urls[0], treeId: treeIds[0], readingTime: 3)
        try db.updateBrowsingTreeStats(treeId: treeIds[0]) {
            $0.lifeTime = 8
            $0.readingTime = 10
        }
        var results = try db.getPinTabSuggestionCandidates(minDayCount: 2, minTabReadingTimeShare: 0.5, minAverageTabLifetime: 10, dayRange: 30, maxRows: 1)
        XCTAssertEqual(results.count, 0)

        //observed days are ok but not other factors
        BeamDate.travel(24 * 60 * 60)
        try db.addDomainPath0ReadingDay(domainPath0: urls[0], date: BeamDate.now)
        results = try db.getPinTabSuggestionCandidates(minDayCount: 2, minTabReadingTimeShare: 0.5, minAverageTabLifetime: 10, dayRange: 30, maxRows: 1)
        XCTAssertEqual(results.count, 0)

        //enough observed days, tree share of readtime and tree average life over threshold
        try db.updateDomainPath0TreeStat(domainPath0: urls[0], treeId: treeIds[1], readingTime: 8)
        try db.updateBrowsingTreeStats(treeId: treeIds[1]) {
            $0.lifeTime = 13
            $0.readingTime = 10
        }
        results = try db.getPinTabSuggestionCandidates(minDayCount: 2, minTabReadingTimeShare: 0.5, minAverageTabLifetime: 10, dayRange: 30, maxRows: 1)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].domainPath0, "https://site.a/path")
        XCTAssertEqual(results[0].score, 2 * (3 + 8) / 20 * (8 + 13) / 2)
        //BeamDate.reset()
    }

    func testSuggester() {
        class FakeDomainPath0Storage: DomainPath0TreeStatsStorageProtocol {
            init(minReadDay: Date) {
                self.domainPath0MinReadDay = minReadDay
            }

            var domainPath0MinReadDay : Date?

            func update(treeId: UUID, url: String, readTime: Double, date: Date) {}
            func update(treeId: UUID, lifeTime: Double) {}
            func cleanUp(olderThan days: Int, maxRows: Int) {}
            func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float, dayRange: Int, maxRows: Int) -> [ScoredDomainPath0] {
                return [
                    ScoredDomainPath0(domainPath0: "https://abc.com/path", score: 1),
                    ScoredDomainPath0(domainPath0: "https://def.fr/path", score: 1),
                    ScoredDomainPath0(domainPath0: "https://www.google.com/search", score: 0.5)

                ]
            }
        }
        let testParameters = TabPinSuggestionParameters(
            domainPath0minDayCount: 3,
            minTabReadingTimeShare: 0.5,
            minAverageTabLifetime: 60, //seconds
            minObservationDays: 7,
            candidateRefreshMinInterval: Double(1 * 60 * 60),
            maxSuggestionCount: 2
        )
        let db = GRDBDatabase.empty()
        let suggestionMemory = TabPinSuggestionMemory(db: db)
        BeamDate.freeze("2001-01-01T00:00:00+000")
        let suggester = TabPinSuggester(
            storage: FakeDomainPath0Storage(minReadDay: BeamDate.now),
            suggestionMemory: suggestionMemory,
            parameters: testParameters
        )
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://abc.com/path/page.html")!))
        BeamDate.travel(Double(15 * 24 * 60 * 60))
        XCTAssertTrue(suggester.isEligible(url: URL(string: "https://abc.com/path/page.html")!))
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://def.com/path/page.html")!))
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://www.google.com/search?q=keyword")!))
        //can't suggest twice on the same domain path
        suggester.hasSuggested(url: URL(string: "https://abc.com/path/page.html")!)
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://abc.com/path/page2.html")!))

        //once suggester has suggested over testParameters.maxSuggestionCount, it stops suggesting
        XCTAssertTrue(suggester.isEligible(url: URL(string: "https://def.fr/path/page.html")!))
        suggester.hasSuggested(url: URL(string: "https://ghi.com/path/page.html")!)
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://def.fr/path/page.html")!))

        //suggester also stops suggesting when the user has pinned
        suggestionMemory.reset()
        XCTAssert(suggester.isEligible(url: URL(string: "https://abc.com/path/page.html")!))
        suggester.hasPinned()
        XCTAssertFalse(suggester.isEligible(url: URL(string: "https://abc.com/path/page.html")!))
        //BeamDate.reset()
    }

    func testTabPinSuggestionMemory() {
        let memory = TabPinSuggestionMemory(db: GRDBDatabase.empty())
        XCTAssertEqual(memory.tabPinSuggestionCount, 0)
        memory.addTabPinSuggestion(domainPath0: "http://abc.com")
        memory.addTabPinSuggestion(domainPath0: "http://abc.com")
        memory.addTabPinSuggestion(domainPath0: "http://def.fr")
        XCTAssertEqual(memory.tabPinSuggestionCount, 2)
        XCTAssert(memory.alreadyPinTabSuggested(domainPath0: "http://abc.com"))
        XCTAssert(memory.alreadyPinTabSuggested(domainPath0: "http://def.fr"))
        XCTAssertFalse(memory.alreadyPinTabSuggested(domainPath0: "http://ghi.gr"))
        memory.reset()
        XCTAssertEqual(memory.tabPinSuggestionCount, 0)
    }
}
