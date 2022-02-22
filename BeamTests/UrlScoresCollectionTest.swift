//
//  UrlScoresCollectionTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 12/07/2021.
//
@testable import BeamCore
@testable import Beam

import XCTest
private typealias Table = [UUID: LongTermUrlScore]


class UrlScoresCollectionTest: XCTestCase {
    class FakeLongTermScoreStore: LongTermUrlScoreStoreProtocol {
        fileprivate var data = Table()
        func apply(to urlId: UUID, changes: (LongTermUrlScore) -> Void) {
            let score = data[urlId] ?? LongTermUrlScore(urlId: urlId)
            changes(score)
            data[urlId] = score
        }
        func getMany(urlIds: [UUID]) -> [UUID: LongTermUrlScore] {
            return [:]
        }
    }
    
    func testNodeCreationScores() throws {
        //first url is visited once then sencond url and first url once again

        let store = FakeLongTermScoreStore()
        let firstUrl = "www.poivre.com"
        let secondUrl = "www.sel.fr"
        let tree = BrowsingTree(nil, frecencyScorer: nil, longTermScoreStore: store)
        tree.navigateTo(url: firstUrl, title: nil, startReading: true, isLinkActivation: false, readCount: 50)
        let firstNode = try XCTUnwrap(tree.current)
        let firstLink = firstNode.link
        var score = try XCTUnwrap(store.data[firstLink])
    
        XCTAssertEqual(score.urlId, firstLink)
        XCTAssertEqual(score.visitCount, 1)
        XCTAssertEqual(score.readingTimeToLastEvent, 0)
        XCTAssertEqual(score.textSelections, 0)
        XCTAssertEqual(score.scrollRatioX, 0)
        XCTAssertEqual(score.scrollRatioY, 0)
        XCTAssertEqual(score.textAmount, 50)
        XCTAssertEqual(score.area, 0)
        XCTAssertEqual(score.lastCreationDate, firstNode.events.first?.date)

        tree.navigateTo(url: secondUrl, title: nil, startReading: true, isLinkActivation: false, readCount: 0)
        tree.navigateTo(url: firstUrl, title: nil, startReading: true, isLinkActivation: false, readCount: 100)
        tree.switchToBackground()

        let secondNode = try XCTUnwrap(tree.current)
        score = try XCTUnwrap(store.data[firstLink])
        let firstStartReading = firstNode.events[1].date
        let firstEndReading = try XCTUnwrap(firstNode.events.last?.date)
        let secondStartReading = secondNode.events[1].date
        let secondEndReading = try XCTUnwrap(secondNode.events.last?.date)

        let expectedDuration = firstEndReading.timeIntervalSince(firstStartReading) + secondEndReading.timeIntervalSince(secondStartReading)

        XCTAssertEqual(score.urlId, firstLink)
        XCTAssertEqual(score.visitCount, 2)
        XCTAssertEqual(score.readingTimeToLastEvent, expectedDuration)
        XCTAssertEqual(score.textSelections, 0)
        XCTAssertEqual(score.scrollRatioX, 0)
        XCTAssertEqual(score.scrollRatioY, 0)
        XCTAssertEqual(score.textAmount, 100)
        XCTAssertEqual(score.area, 0)
        XCTAssertEqual(score.lastCreationDate, secondNode.events.first?.date)
    }

    func testJsRelatedScores() throws {
        let config = BeamWebViewConfigurationBase()
        let webView = BeamWebView(frame: CGRect(), configuration: config)
        let page = WebPageBaseImpl(webView: webView)
        let store = FakeLongTermScoreStore()
        let tree = BrowsingTree(nil, frecencyScorer: nil, longTermScoreStore: store)
        let scorer = BrowsingTreeScorer(browsingTree: tree)
        page.browsingScorer = scorer
        scorer.page = page
        let positions = WebPositions()
        page.webPositions = positions

        let creationDate = try XCTUnwrap(tree.root.events.first?.date)
        let link = tree.root.link

        //adding text section
        scorer.addTextSelection()
        var score = try XCTUnwrap(store.data[link])
    
        XCTAssertEqual(score.urlId, link)
        XCTAssertEqual(score.visitCount, 1)
        XCTAssertEqual(score.readingTimeToLastEvent, 0)
        XCTAssertEqual(score.textSelections, 1)
        XCTAssertEqual(score.scrollRatioX, 0)
        XCTAssertEqual(score.scrollRatioY, 0)
        XCTAssertEqual(score.textAmount, 0)
        XCTAssertEqual(score.area, 0)
        XCTAssertEqual(score.lastCreationDate, creationDate)

        guard page.webPositions != nil else {
            XCTFail("expected test page")
            return
        }

        //first scroll
        let scroll1 = WebPositions.FrameInfo(
            href: "https://example.com",
            parentHref: "https://example.com",
            x: 0,
            y: 0,
            scrollX: 2,
            scrollY: 5,
            width: 10,
            height: 10
        )

        scorer.updateScrollingScore(scroll1)
        score = try XCTUnwrap(store.data[link])
        
        XCTAssertEqual(score.urlId, link)
        XCTAssertEqual(score.visitCount, 1)
        XCTAssertEqual(score.readingTimeToLastEvent, 0)
        XCTAssertEqual(score.textSelections, 1)
        XCTAssertEqual(score.scrollRatioX, 0.2)
        XCTAssertEqual(score.scrollRatioY, 0.5)
        XCTAssertEqual(score.textAmount, 0)
        XCTAssertEqual(score.area, 100)
        XCTAssertEqual(score.lastCreationDate, creationDate)
        
        //second scroll
        let scroll2 = WebPositions.FrameInfo(
            href: "https://example.com",
            parentHref: "https://example.com",
            x: 0,
            y: 0,
            scrollX: 8,
            scrollY: 4,
            width: 20,
            height: 20
        )
        scorer.updateScrollingScore(scroll2)
        score = try XCTUnwrap(store.data[link])
        
        XCTAssertEqual(score.urlId, link)
        XCTAssertEqual(score.visitCount, 1)
        XCTAssertEqual(score.readingTimeToLastEvent, 0)
        XCTAssertEqual(score.textSelections, 1)
        XCTAssertEqual(score.scrollRatioX, 0.4) //max of current and previous score
        XCTAssertEqual(score.scrollRatioY, 0.5) //max of current and previous score
        XCTAssertEqual(score.textAmount, 0)
        XCTAssertEqual(score.area, 400) // gets overwritten
        XCTAssertEqual(score.lastCreationDate, creationDate)
    }
}
