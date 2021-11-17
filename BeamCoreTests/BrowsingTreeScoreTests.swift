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
        let now = BeamDate.now
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
        score0.lastEvent = ReadingEvent(type: .closeTab, date: BeamDate.now)
        let score1 = Score()
        score1.lastCreationDate = Date(timeIntervalSinceNow: -1 * 60 * 60)
        score1.lastEvent = ReadingEvent(type: .switchToBackground, date: BeamDate.now)

        //score0 is less than score1 because score 0 last event is closing
        XCTAssert(score0.clusteringRemovalLessThan(score1, date: BeamDate.now))
        XCTAssert(!score1.clusteringRemovalLessThan(score0, date: BeamDate.now))

        //both scores are not isClosed so score1 is below score0 because its linkRemovalScore is lower
        score0.lastEvent = ReadingEvent(type: .switchToBackground, date: BeamDate.now)
        XCTAssert(score1.clusteringRemovalLessThan(score0, date: BeamDate.now))
    }

    func testNodeVisitType() {
        // First case: root node
        let tree0 = BrowsingTree(nil)
        XCTAssertEqual(tree0.current.visitType, FrecencyEventType.webRoot)

        func testRootChildVisitType(origin: BrowsingTreeOrigin, expected visitType: FrecencyEventType) {
            let tree = BrowsingTree(origin)
            tree.navigateTo(url: "www.google.com?q=beam", title: nil, startReading: true, isLinkActivation: true, readCount: 10)
            XCTAssertEqual(tree.current.visitType, visitType)
        }

        // Second case: root direct children
        testRootChildVisitType(origin: BrowsingTreeOrigin.searchBar(query: "beam"), expected: FrecencyEventType.webSearchBar)
        testRootChildVisitType(origin: BrowsingTreeOrigin.searchFromNode(nodeText: "beam"), expected: FrecencyEventType.webFromNote)
        testRootChildVisitType(origin: BrowsingTreeOrigin.linkFromNote(noteName: "beam beam"), expected: FrecencyEventType.webFromNote)
        testRootChildVisitType(origin: BrowsingTreeOrigin.browsingNode(id: UUID(), pageLoadId: nil, rootOrigin: nil), expected: FrecencyEventType.webLinkActivation)

        //controls visitType value of a root grand child node
        func testAnyOtherNodeVisitType(isLinkActivation: Bool, expected visitType: FrecencyEventType) {
            let tree = BrowsingTree(nil)
            tree.navigateTo(url: "www.somesite.com", title: nil, startReading: true, isLinkActivation: true, readCount: 10)
            tree.navigateTo(url: "www.someothersite.com", title: nil, startReading: true, isLinkActivation: isLinkActivation, readCount: 10)
            XCTAssertEqual(tree.current.visitType, visitType)
        }
        //Third case: any other node
        testAnyOtherNodeVisitType(isLinkActivation: true, expected: FrecencyEventType.webLinkActivation)
        testAnyOtherNodeVisitType(isLinkActivation: false, expected: FrecencyEventType.webSearchBar)
    }

    struct UpdateScoreArgs {
        let id: UUID
        let scoreValue: Float
        let eventType: FrecencyEventType
        let date: Date
        let paramKey: FrecencyParamKey
    }

    class FakeFrecencyScorer: FrecencyScorer {
        public var updateCalls = [UpdateScoreArgs]()
        func update(id: UUID, value: Float, eventType: FrecencyEventType, date: Date, paramKey: FrecencyParamKey) {
            let args = UpdateScoreArgs(id: id, scoreValue: value, eventType: eventType, date: date, paramKey: paramKey)
            updateCalls.append(args)
        }
    }

    func testFrecencyWrite() {
        //checks that frecency writer is called with right values
        func testCall(call: UpdateScoreArgs, expectedUrlId urlId: UUID, expectedValue value: Float, expectedEventType eventType: FrecencyEventType, expectedDate date: Date, expectedKey paramKey: FrecencyParamKey) {
            XCTAssertEqual(call.id, urlId)
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
        guard let fakeFrecencyScorer = tree.frecencyScorer as? FakeFrecencyScorer else {
            fatalError("frecencyScorer should be a FakeFrecencyScorer")
        }
        let updateScoreCalls = fakeFrecencyScorer.updateCalls
        //root visit has no read period so only info at creation is sent
        testCall(call: updateScoreCalls[0], expectedUrlId: root.link, expectedValue: 1, expectedEventType: .webRoot, expectedDate: rootCreationDate, expectedKey: .webVisit30d0)
        //child parent is root and tree origin is search so child visit type is .searchBar
        testCall(call: updateScoreCalls[1], expectedUrlId: child.link, expectedValue: 1, expectedEventType: .webSearchBar, expectedDate: childCreationDate, expectedKey: .webVisit30d0)
        testCall(call: updateScoreCalls[2], expectedUrlId: child.link, expectedValue: readDuration, expectedEventType: .webSearchBar, expectedDate: readStart, expectedKey: .webReadingTime30d0)
    }
}
