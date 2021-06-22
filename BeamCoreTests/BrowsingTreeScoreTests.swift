//
//  BrowsingTreeScoreTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 28/05/2021.
//

import XCTest

@testable import BeamCore

class BrowsingTreeScoreTests: XCTestCase {

    func testReadingTime() throws {
        let tree = BrowsingTree(nil) //underlying url is <???>
        let link = tree.current.link
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 0)
        //foreground start
        tree.current.addEvent(ReadingEventType.startReading, date: Date(timeIntervalSinceReferenceDate: 1))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 0)
        //on foreground for 2 sec
        tree.current.addEvent(ReadingEventType.openLinkInNewTab, date: Date(timeIntervalSinceReferenceDate: 3))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 2)
        //to background
        tree.current.addEvent(ReadingEventType.switchToBackground, date: Date(timeIntervalSinceReferenceDate: 4))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 3)
        //start foreground
        tree.current.addEvent(ReadingEventType.startReading, date: Date(timeIntervalSinceReferenceDate: 1000))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 3)
        //on foreground for 1 sec
        tree.current.addEvent(ReadingEventType.startReading, date: Date(timeIntervalSinceReferenceDate: 1001))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeToLastEvent, 4)
        //exit foreground
        tree.current.addEvent(ReadingEventType.closeTab, date: Date(timeIntervalSinceReferenceDate: 1001))

        tree.navigateTo(url: "www.google.com", title: nil, startReading: false, isLinkActivation: false, readCount: 200)

        tree.navigateTo(url: "<???>", title: nil, startReading: false, isLinkActivation: false, readCount: 300)
        //start foreground
        tree.current.addEvent(ReadingEventType.startReading, date: Date(timeIntervalSinceReferenceDate: 1003))
        //on foreground for 1 sec
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeScore(toDate: Date(timeIntervalSinceReferenceDate: 1004)), 5)

        tree.current.addEvent(ReadingEventType.switchToBackground, date: Date(timeIntervalSinceReferenceDate: 1004))
        XCTAssertEqual(tree.scoreFor(link: link).readingTimeScore(toDate: Date(timeIntervalSinceReferenceDate: 2000)), 5)

    }

    func testLastCreationDate() throws {
        let tree = BrowsingTree(nil)
        let link = tree.current.link
        let date0 = tree.current.events[0].date
        XCTAssertEqual(tree.scoreFor(link: link).lastCreationDate, date0)
        tree.navigateTo(url: "www.google.com", title: nil, startReading: false, isLinkActivation: false, readCount: 400)
        XCTAssertEqual(tree.scoreFor(link: link).lastCreationDate, date0)
        tree.navigateTo(url: "<???>", title: nil, startReading: false, isLinkActivation: false, readCount: 500)
        let date1 = tree.current.events[0].date
        XCTAssertEqual(tree.scoreFor(link: link).lastCreationDate, date1)
    }

    func testScoreHalflive() throws {
        let score = Score()
        let now = Date()
        score.textAmount = 1
        score.lastCreationDate = now
        let clusteringScore = score.clusteringScore(date: now)
        let halfLife = 30.0 * 60.0
        let removalScore = score.clusteringRemovalScore(date: now + halfLife)
        XCTAssertEqual(0.5 * clusteringScore, removalScore)
    }

    func testLinkRemovalComparison() {
        let score0 = Score()
        score0.lastCreationDate = Date(timeIntervalSinceNow: -0.5 * 60 * 60)
        score0.lastEvent = ReadingEvent(type: .closeTab, date: Date())
        let score1 = Score()
        score1.lastCreationDate = Date(timeIntervalSinceNow: -1 * 60 * 60)
        score1.lastEvent = ReadingEvent(type: .switchToBackground, date: Date())

        //score0 is less than score1 because score 0 last event is closing
        XCTAssert(score0.clusteringRemovalLessThan(score1, date: Date()))
        XCTAssert(!score1.clusteringRemovalLessThan(score0, date: Date()))

        //both scores are not isClosed so score1 is below score0 because its linkRemovalScore is lower
        score0.lastEvent = ReadingEvent(type: .switchToBackground, date: Date())
        XCTAssert(score1.clusteringRemovalLessThan(score0, date: Date()))
    }
    func testDeserialization() {

        let jsonTree = """
        {"origin": {"type": "searchBar", "value": "patrick dewaere"},
         "root": {"children": [{"events": [{"date": 643295386.78019,
                                            "type": "creation"},
                                           {"date": 643295386.780228,
                                            "type": "startReading"},
                                           {"date": 643295391.950899,
                                            "type": "navigateToLink"},
                                           {"date": 643295421.472989,
                                            "type": "startReading"},
                                           {"date": 643295439.820442,
                                            "type": "navigateToLink"},
                                           {"date": 643295446.507388,
                                            "type": "startReading"}],
                                "id": "4045225C-5E34-4520-9C46-BC7450837F6F",
                                "link": 218}],
                  "events": [{"date": 643295384.698409, "type": "creation"},
                             {"date": 643295385.234729, "type": "startReading"},
                             {"date": 643295386.780153, "type": "searchBarNavigation"}],
                  "id": "313D8A29-1C6D-4A0A-9970-12293C1CCA2B",
                  "link": 78},
         "scores": [218,
                    {"area": 3747357,
                     "inbounds": 0,
                     "openIndex": 0,
                     "outbounds": 0,
                     "readingTime": 0,
                     "scrollRatioX": 0,
                     "scrollRatioY": 0.34304097294807434,
                     "textAmount": 1594,
                     "textSelections": 0,
                     "videoReadingDuration": 0,
                     "videoTotalDuration": 0}]}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        do {
            _ = try decoder.decode(BrowsingTree.self, from: jsonTree)
        } catch { XCTFail("Error: \(error)") }
    }

    func testNodeVisitType() {
        // First case: root node
        let tree0 = BrowsingTree(nil)
        XCTAssertEqual(tree0.current.visitType, VisitType.root)

        func testRootChildVisitType(origin: BrowsingTreeOrigin, expected visitType: VisitType) {
            let tree = BrowsingTree(origin)
            tree.navigateTo(url: "www.google.com?q=beam", title: nil, startReading: true, isLinkActivation: true, readCount: 10)
            XCTAssertEqual(tree.current.visitType, visitType)
        }

        // Second case: root direct children
        testRootChildVisitType(origin: BrowsingTreeOrigin.searchBar(query: "beam"), expected: VisitType.searchBar)
        testRootChildVisitType(origin: BrowsingTreeOrigin.searchFromNode(nodeText: "beam"), expected: VisitType.fromNote)
        testRootChildVisitType(origin: BrowsingTreeOrigin.linkFromNote(noteName: "beam beam"), expected: VisitType.fromNote)
        testRootChildVisitType(origin: BrowsingTreeOrigin.browsingNode(id: UUID()), expected: VisitType.linkActivation)

        //controls visitType value of a root grand child node
        func testAnyOtherNodeVisitType(isLinkActivation: Bool, expected visitType: VisitType) {
            let tree = BrowsingTree(nil)
            tree.navigateTo(url: "www.somesite.com", title: nil, startReading: true, isLinkActivation: true, readCount: 10)
            tree.navigateTo(url: "www.someothersite.com", title: nil, startReading: true, isLinkActivation: isLinkActivation, readCount: 10)
            XCTAssertEqual(tree.current.visitType, visitType)
        }
        //Third case: any other node
        testAnyOtherNodeVisitType(isLinkActivation: true, expected: VisitType.linkActivation)
        testAnyOtherNodeVisitType(isLinkActivation: false, expected: VisitType.searchBar)
    }

    struct UpdateScoreArgs {
        let urlId: UInt64
        let scoreValue: Float
        let visitType: VisitType
        let date: Date
        let paramKey: FrecencyParamKey
    }

    class FakeFrecencyScorer: FrecencyScorer {
        public var updateCalls = [UpdateScoreArgs]()
        func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey) {
            let args = UpdateScoreArgs(urlId: urlId, scoreValue: value, visitType: visitType, date: date, paramKey: paramKey)
            updateCalls.append(args)
        }
        func rank(urlIds: [UInt64], paramKey: FrecencyParamKey, date: Date) -> [UInt64] {
            return [UInt64]()
        }
    }

    func testFrecencyWrite() {
        //checks that frecency writer is called with right values
        func testCall(call: UpdateScoreArgs, expectedUrlId urlId: UInt64, expectedValue value: Float, expectedVisitType visitType: VisitType, expectedDate date: Date, expectedKey paramKey: FrecencyParamKey) {
            XCTAssertEqual(call.urlId, urlId)
            XCTAssertEqual(call.scoreValue, value)
            XCTAssertEqual(call.date, date)
            XCTAssertEqual(call.paramKey, paramKey)
        }

        let fakeScorer = FakeFrecencyScorer()
        let tree = BrowsingTree(BrowsingTreeOrigin.searchBar(query: "some weird keywords"), frecencyScorer: fakeScorer)
        let root = tree.root!
        let rootCreationDate = root.events[0].date
        tree.navigateTo(url: "www.somesite.com", title: nil, startReading: true, isLinkActivation: true, readCount: 10)
        tree.switchToOtherTab()
        let child = tree.current!
        let childCreationDate = child.events[0].date
        let readStart = child.events[1].date
        let readEnd = child.events[2].date
        let readDuration = Float(readEnd.timeIntervalSince(readStart))
        let updateScoreCalls = (tree.frecencyScorer as! FakeFrecencyScorer).updateCalls

        //root visit has no read period so only info at creation is sent
        testCall(call: updateScoreCalls[0], expectedUrlId: root.link, expectedValue: 1, expectedVisitType: .root, expectedDate: rootCreationDate, expectedKey: .visit30d0)
        //child parent is root and tree origin is search so child visit type is .searchBar
        testCall(call: updateScoreCalls[1], expectedUrlId: child.link, expectedValue: 1, expectedVisitType: .searchBar, expectedDate: childCreationDate, expectedKey: .visit30d0)
        testCall(call: updateScoreCalls[2], expectedUrlId: child.link, expectedValue: readDuration, expectedVisitType: .searchBar, expectedDate: readStart, expectedKey: .readingTime30d0)
    }
}
