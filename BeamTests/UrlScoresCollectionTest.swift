//
//  UrlScoresCollectionTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/07/2021.
//
@testable import BeamCore
@testable import Beam

import XCTest


class UrlScoresCollectionTest: XCTestCase {
    class FakeDailyScoreStore: DailyUrlScoreStoreProtocol {
        fileprivate var data = [UUID: DailyURLScore]()
        func apply(to urlId: UUID, changes: (DailyURLScore) -> Void) {
            let score = data[urlId] ?? DailyURLScore(urlId: urlId, localDay: "0000-00-00")
            changes(score)
            data[urlId] = score
        }
        func getScores(daysAgo: Int) -> [UUID: DailyURLScore] { [:] }
        func getAggregatedScores(between offset0: Int, and offset1: Int) -> [UUID : AggregatedURLScore] { [UUID:AggregatedURLScore]() }
        func getDailyRepeatingUrlsWithoutFragment(between offset0: Int, and offset1: Int, minRepeat: Int) -> Set<String> { Set<String>() }
        func getUrlWithoutFragmentDistinctVisitDayCount(between offset0: Int, and offset1: Int) -> [String : Int] { [String: Int]() }
    }
    
    func testNodeCreationScores() throws {
        //first url is visited once then sencond url and first url once again

        let dailyStore = FakeDailyScoreStore()
        let firstUrl = "www.poivre.com"
        let secondUrl = "www.sel.fr"
        let tree = BrowsingTree(nil, frecencyScorer: nil, dailyScoreStore: dailyStore)
        tree.navigateTo(url: firstUrl, title: nil, startReading: true, isLinkActivation: false)
        tree.update(for: firstUrl, readCount: 50)
        let firstNode = try XCTUnwrap(tree.current)
        let firstLink = firstNode.link
        var dailyScore = try XCTUnwrap(dailyStore.data[firstLink])

        XCTAssertEqual(dailyScore.urlId, firstLink)
        XCTAssertEqual(dailyScore.visitCount, 1)
        XCTAssertEqual(dailyScore.readingTimeToLastEvent, 0)
        XCTAssertEqual(dailyScore.textSelections, 0)
        XCTAssertEqual(dailyScore.scrollRatioX, 0)
        XCTAssertEqual(dailyScore.scrollRatioY, 0)
        XCTAssertEqual(dailyScore.textAmount, 50)
        XCTAssertEqual(dailyScore.area, 0)
        XCTAssertEqual(dailyScore.navigationCountSinceLastSearch, 0)

        tree.navigateTo(url: secondUrl, title: nil, startReading: true, isLinkActivation: false)
        tree.update(for: firstUrl, readCount: 100)
        tree.navigateTo(url: firstUrl, title: nil, startReading: true, isLinkActivation: false)
        tree.switchToBackground()

        let secondNode = try XCTUnwrap(tree.current)
        dailyScore = try XCTUnwrap(dailyStore.data[firstLink])
        let firstStartReading = firstNode.events[1].date
        let firstEndReading = try XCTUnwrap(firstNode.events.last?.date)
        let secondStartReading = secondNode.events[1].date
        let secondEndReading = try XCTUnwrap(secondNode.events.last?.date)

        let expectedDuration = firstEndReading.timeIntervalSince(firstStartReading) + secondEndReading.timeIntervalSince(secondStartReading)

        XCTAssertEqual(dailyScore.urlId, firstLink)
        XCTAssertEqual(dailyScore.visitCount, 2)
        XCTAssertEqual(dailyScore.readingTimeToLastEvent, expectedDuration)
        XCTAssertEqual(dailyScore.textSelections, 0)
        XCTAssertEqual(dailyScore.scrollRatioX, 0)
        XCTAssertEqual(dailyScore.scrollRatioY, 0)
        XCTAssertEqual(dailyScore.textAmount, 100)
        XCTAssertEqual(dailyScore.area, 0)
        XCTAssertEqual(dailyScore.navigationCountSinceLastSearch, 0)
    }

    func testJsRelatedScores() throws {
        let config = BeamWebViewConfigurationBase()
        let webView = BeamWebView(frame: CGRect(), configuration: config)
        let page = WebPageBaseImpl(webView: webView)
        let dailyStore = FakeDailyScoreStore()
        let tree = BrowsingTree(nil, frecencyScorer: nil, dailyScoreStore: dailyStore)
        let scorer = BrowsingTreeScorer(browsingTree: tree)
        page.browsingScorer = scorer
        scorer.page = page
        let frames = WebFrames()
        let positions = WebPositions(webFrames: frames)
        page.webFrames = frames
        page.webPositions = positions

        let link = tree.root.link

        //adding text section
        scorer.addTextSelection()
        var dailyScore = try XCTUnwrap(dailyStore.data[link])

        XCTAssertEqual(dailyScore.urlId, link)
        XCTAssertEqual(dailyScore.visitCount, 1)
        XCTAssertEqual(dailyScore.readingTimeToLastEvent, 0)
        XCTAssertEqual(dailyScore.textSelections, 1)
        XCTAssertEqual(dailyScore.scrollRatioX, 0)
        XCTAssertEqual(dailyScore.scrollRatioY, 0)
        XCTAssertEqual(dailyScore.textAmount, 0)
        XCTAssertEqual(dailyScore.area, 0)

        //first scroll
        let scroll1 = WebFrames.FrameInfo(
            href: "https://example.com",
            parentHref: "https://example.com",
            x: 0,
            y: 0,
            scrollX: 2,
            scrollY: 5,
            scrollWidth: 10,
            scrollHeight: 10,
            width: 1,
            height: 1
        )

        scorer.updateScrollingScore(scroll1)
        dailyScore = try XCTUnwrap(dailyStore.data[link])

        XCTAssertEqual(dailyScore.urlId, link)
        XCTAssertEqual(dailyScore.visitCount, 1)
        XCTAssertEqual(dailyScore.readingTimeToLastEvent, 0)
        XCTAssertEqual(dailyScore.textSelections, 1)
        XCTAssertEqual(dailyScore.scrollRatioX, 0.2)
        XCTAssertEqual(dailyScore.scrollRatioY, 0.5)
        XCTAssertEqual(dailyScore.textAmount, 0)
        XCTAssertEqual(dailyScore.area, 100)

        //second scroll
        let scroll2 = WebFrames.FrameInfo(
            href: "https://example.com",
            parentHref: "https://example.com",
            x: 0,
            y: 0,
            scrollX: 8,
            scrollY: 4,
            scrollWidth: 20,
            scrollHeight: 20,
            width: 1,
            height: 1
        )
        scorer.updateScrollingScore(scroll2)
        dailyScore = try XCTUnwrap(dailyStore.data[link])

        XCTAssertEqual(dailyScore.urlId, link)
        XCTAssertEqual(dailyScore.visitCount, 1)
        XCTAssertEqual(dailyScore.readingTimeToLastEvent, 0)
        XCTAssertEqual(dailyScore.textSelections, 1)
        XCTAssertEqual(dailyScore.scrollRatioX, 0.4) //max of current and previous score
        XCTAssertEqual(dailyScore.scrollRatioY, 0.5) //max of current and previous score
        XCTAssertEqual(dailyScore.textAmount, 0)
        XCTAssertEqual(dailyScore.area, 400) // gets overwritten

        //doesn't create nan score with nan scrolls
        let scroll3 = WebFrames.FrameInfo(
            href: "https://example.com",
            parentHref: "https://example.com",
            x: 0,
            y: 0,
            scrollX: CGFloat.nan,
            scrollY: CGFloat.nan,
            scrollWidth: 20,
            scrollHeight: 20,
            width: 1,
            height: 1
        )
        scorer.updateScrollingScore(scroll3)
    }

    func testDailyIsPinned() throws {
        let dailyStore = FakeDailyScoreStore()
        let tree = BrowsingTree(nil, frecencyScorer: nil, dailyScoreStore: dailyStore)
        tree.navigateTo(url: "http://abc.com", title: "", startReading: false, isLinkActivation: false)
        let urlId0 = tree.current.link
        tree.navigateTo(url: "http://def.com", title: "", startReading: false, isLinkActivation: false)
        let urlId1 = tree.current.link
        tree.isPinned = true
        tree.navigateTo(url: "http://ghi.com", title: "", startReading: false, isLinkActivation: false)
        let urlId2 = tree.current.link
        tree.isPinned = false

        //tree wasn't pinned when url was loaded
        XCTAssertEqual(dailyStore.data[urlId0]?.isPinned, false)
        //pinned occured while page was loaded
        XCTAssertEqual(dailyStore.data[urlId1]?.isPinned, true)
        //tree was already pinned when url loaded and unpinning has no effect on score
        XCTAssertEqual(dailyStore.data[urlId2]?.isPinned, true)
    }
}
