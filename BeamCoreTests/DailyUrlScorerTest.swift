//
//  DailyUrlScorerTest.swift
//  BeamCoreTests
//
//  Created by Paul Lefkopoulos on 28/04/2022.
//

import XCTest
@testable import BeamCore

private class FakeDailyScoreStore: DailyUrlScoreStoreProtocol {
    let scores: [UUID: AggregatedURLScore]
    init(scores: [UUID: AggregatedURLScore], repeatedUrls: Set<String> = Set<String>()) {
        self.scores = scores
    }
    func apply(to urlId: UUID, changes: (DailyURLScore) -> Void) {}
    func getScores(daysAgo: Int) -> [UUID: DailyURLScore] { [UUID: DailyURLScore]() }
    func getAggregatedScores(between offset0: Int, and offset1: Int) -> [UUID: AggregatedURLScore] { scores }
    func getDailyRepeatingUrlsWithoutFragment(between offset0: Int, and offset1: Int, minRepeat: Int) -> Set<String> { Set<String>() }
    func getUrlWithoutFragmentDistinctVisitDayCount(between offset0: Int, and offset1: Int) -> [String: Int] { [String: Int]() }
}

class DailyUrlScorerTest: XCTestCase {

    override func setUpWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in}
    }

    override func tearDownWithError() throws {
        LinkStore.shared.deleteAll(includedRemote: false) { _ in }
    }

    func testUrlGrouping() throws {
        let urls = [
            URL(string: "http://abc.com/page#anchor0")!,
            URL(string: "http://abc.com/page#anchor1")!,
            URL(string: "http://def.org/")!
            ]
        let urlIds = [
            [UUID(), UUID()],
            [UUID()],
            [UUID(), UUID()]
        ]
        let initialGroups = [
            urls[0]: urlIds[0],
            urls[1]: urlIds[1],
            urls[2]: urlIds[2]
        ]
        let groups = UrlGroups(groups: initialGroups)
        let regrouped = groups.regroup { $0.fragmentRemoved }
        XCTAssertEqual(regrouped.groups.count, 2)
        let newGroup0 = try XCTUnwrap(regrouped.groups[URL(string: "http://abc.com/page")!])
        XCTAssertEqual(Set(newGroup0), Set(urlIds[0] + urlIds[1]))

        let newGroup1 = try XCTUnwrap(regrouped.groups[URL(string: "http://def.org/")!])
        XCTAssertEqual(newGroup1, urlIds[2])
    }

    func testUrlHTTPSchemeGrouping() throws {
        let urls = [
            URL(string: "http://abc.com/page")!,
            URL(string: "https://abc.com/page")!,
            URL(string: "somethingelse://abc.com/page")!,
            URL(string: "http://def.org/")!,
            URL(string: "https://geh.gr/")!

            ]
        let urlIds = [
            [UUID(), UUID()],
            [UUID(), UUID()],
            [UUID()],
            [UUID()],
            [UUID()]
        ]
        let initialGroups = Dictionary(uniqueKeysWithValues: zip(urls, urlIds))
        let groups = UrlGroups(groups: initialGroups)
        let regrouped = groups.groupHTTPSchemes
        XCTAssertEqual(regrouped.groups.count, 4)
        let newGroup0 = try XCTUnwrap(regrouped.groups[URL(string: "https://abc.com/page")!])
        XCTAssertEqual(Set(newGroup0), Set(urlIds[0] + urlIds[1]))

        let newGroup1 = try XCTUnwrap(regrouped.groups[URL(string: "somethingelse://abc.com/page")!])
        XCTAssertEqual(newGroup1, urlIds[2])

        let newGroup2 = try XCTUnwrap(regrouped.groups[URL(string: "http://def.org/")!])
        XCTAssertEqual(newGroup2, urlIds[3])

        let newGroup3 = try XCTUnwrap(regrouped.groups[URL(string: "https://geh.gr/")!])
        XCTAssertEqual(newGroup3, urlIds[4])
    }

    func testAggregrateScores() throws {
        let urlIds = (0..<3).map { _ in UUID() }
        let groups = [
            URL(string: "http://abc.fr")!: [urlIds[0], urlIds[1]],
            URL(string: "http://def.fr")!: [urlIds[2]]
        ]
        let score0 = AggregatedURLScore(
            visitCount: 1,
            readingTimeToLastEvent: 1.0,
            textSelections: 1,
            scrollRatioX: 0.2,
            scrollRatioY: 0.5,
            textAmount: 2,
            area: 1,
            isPinned: true,
            navigationCountSinceLastSearch: 4
        )
        let score1 = AggregatedURLScore(
            visitCount: 1,
            readingTimeToLastEvent: 1.0,
            textSelections: 1,
            scrollRatioX: 0.5,
            scrollRatioY: 0.2,
            textAmount: 3,
            area: 2,
            isPinned: false,
            navigationCountSinceLastSearch: 2
        )
        let score2 = AggregatedURLScore(
            visitCount: 2
        )
        let scores = [
            urlIds[0]: score0,
            urlIds[1]: score1,
            urlIds[2]: score2
        ]
        let urlGroups = UrlGroups(groups: groups)
        let aggregated = urlGroups.aggregate(scores: scores)
        XCTAssertEqual(aggregated.count, 2)
        let aggScore0 = try XCTUnwrap(aggregated[URL(string: "http://abc.fr")!])
        XCTAssertEqual(aggScore0.visitCount, 2)
        XCTAssertEqual(aggScore0.scrollRatioX, 0.5)
        XCTAssertEqual(aggScore0.scrollRatioY, 0.5)
        XCTAssertEqual(aggScore0.isPinned, true)
        XCTAssertEqual(aggScore0.textSelections, 2)
        XCTAssertEqual(aggScore0.textAmount, 3)
        XCTAssertEqual(aggScore0.readingTimeToLastEvent, 2.0)
        XCTAssertEqual(aggScore0.area, 2)
        XCTAssertEqual(aggScore0.navigationCountSinceLastSearch, 2)

        let aggScore1 = try XCTUnwrap(aggregated[URL(string: "http://def.fr")!])
        XCTAssertEqual(aggScore1.visitCount, 2)
        XCTAssertEqual(aggScore1.scrollRatioX, 0)
        XCTAssertEqual(aggScore1.scrollRatioY, 0)
        XCTAssertEqual(aggScore1.isPinned, false)
        XCTAssertEqual(aggScore1.textSelections, 0)
        XCTAssertEqual(aggScore1.textAmount, 0)
        XCTAssertEqual(aggScore1.readingTimeToLastEvent, 0)
        XCTAssertEqual(aggScore1.area, 0)
        XCTAssertNil(aggScore1.navigationCountSinceLastSearch)
    }

    func testTitleLastDate() {
        let urlIds = (0..<5).map { _ in UUID() }
        let dt = BeamDate.now
        let groups = [
            URL(string: "http://abc.fr")!: [urlIds[0], urlIds[1], urlIds[2]],
            URL(string: "http://def.fr")!: [urlIds[3]],
            URL(string: "http://geh.fr")!: [urlIds[4]]
        ]
        let links = [
            urlIds[0]: Link(url: "http://abc.fr", title: "title 1", content: nil, updatedAt: dt),
            urlIds[1]: Link(url: "http://abc.fr#anchor0", title: "title 2", content: nil, updatedAt: dt + Double(1)),
            urlIds[2]: Link(url: "http://abc.fr#anchor1", title: nil, content: nil, updatedAt: dt + Double(1)),
            urlIds[3]: Link(url: "http://def.fr", title: "title 3", content: nil, updatedAt: dt),
            urlIds[4]: Link(url: "http://ghi.fr", title: nil, content: nil, updatedAt: dt)
        ]
        let urlGroups = UrlGroups(groups: groups)
        let mostRecentTitles = urlGroups.getMostRecentTitles(links: links)
        XCTAssertEqual(mostRecentTitles.count, 2)
        XCTAssertEqual(mostRecentTitles[URL(string: "http://abc.fr")!], "title 2")
        XCTAssertEqual(mostRecentTitles[URL(string: "http://def.fr")!], "title 3")
    }

    func testGetHighScores() {
        let urlsAndTitles = [
            ("https://abc.com/page1#anchor", "title 1"),
            ("http://abc.com/page1", "title 2"),
            ("https://def.com/page1", "title 3"),
            ("https://geh.com/page1", "title 4"), //filtered out because pinned
            ("https://www.google.com/search?q=query", "Google - query"), //filtered out because search query
            ("https://ijk.com/page1", "title 5"), //filtered out because low reading time
            ("https://lmn.com/", "title 6"), //filtered out because is a domain
            ("https://lmn.com/page1", "title 7"), //filtered out because alread pns'd.
            ("https://lmn.com/page2", "title 8") //filtered out because not enough text
        ]
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let urlIds: [UUID] = urlsAndTitles.map {
            BeamDate.travel(1)
            return LinkStore.shared.visit($0.0, title: $0.1, content: nil, destination: nil).id
        }
        let score0 = AggregatedURLScore(
            readingTimeToLastEvent: 1.5,
            textAmount: 500
        )
        let score1 = AggregatedURLScore(
            readingTimeToLastEvent: 1.5,
            textAmount: 500
        )
        let score2 = AggregatedURLScore(
            readingTimeToLastEvent: 2,
            textAmount: 500
        )
        let score3 = AggregatedURLScore(
            readingTimeToLastEvent: 10,
            textAmount: 500,
            isPinned: true
        )
        let score4 = AggregatedURLScore(
            readingTimeToLastEvent: 100,
            textAmount: 500
        )
        let score5 = AggregatedURLScore(
            readingTimeToLastEvent: 0.5,
            textAmount: 10_000
        )
        let score6 = AggregatedURLScore(
            readingTimeToLastEvent: 10,
            textAmount: 500
        )
        let score7 = AggregatedURLScore(
            readingTimeToLastEvent: 10,
            textSelections: 1,
            textAmount: 500
        )
        let score8 = AggregatedURLScore(
            readingTimeToLastEvent: 10_000,
            textAmount: 499
        )

        let scores = [
            urlIds[0]: score0,
            urlIds[1]: score1,
            urlIds[2]: score2,
            urlIds[3]: score3,
            urlIds[4]: score4,
            urlIds[5]: score5,
            urlIds[6]: score6,
            urlIds[7]: score7,
            urlIds[8]: score8
        ]
        let params = DailySummaryUrlParams(minReadingTime: 1, minTextAmount: 500, maxRepeatTimeFrame: 0, maxRepeat: 0)
        let scorer = DailyUrlScorer(store: FakeDailyScoreStore(scores: scores), params: params)
        let scoredUrls = scorer.getHighScoredUrls(between: 0, and: 0, topN: 1)
        XCTAssertEqual(scoredUrls.count, 1)
        //the 2 first url scores got aggregated and title was chosen as most recent.
        XCTAssertEqual(scoredUrls[0].url.absoluteString, "https://abc.com/page1")
        XCTAssertEqual(scoredUrls[0].title, "title 2")
        //https://geh.com is not displayed as is pinned is true

        BeamDate.reset()
    }
}
