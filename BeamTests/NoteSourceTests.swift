//
//  NoteSourceTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 20/07/2021.
//

import XCTest
@testable import Beam
@testable import BeamCore

class NoteSourceTests: XCTestCase {
    private var scoreStore: LongTermUrlScoreStoreProtocol!
    private var sources: NoteSources!
    
    override func setUp() {
        super.setUp()
        sources = NoteSources()
        scoreStore = LongTermUrlScoreStore(db: GRDBDatabase.empty())
    }
    
    func testAdd() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        let now = Date()
        let before = Date() - Double(60.0 * 60.0)

        //added sources can be retreived
        sources.add(urlId: firstUrlId, type: .suggestion, date: before)
        sources.add(urlId: secondUrlId, type: .suggestion, date: before)
        XCTAssertEqual(sources.count, 2)
        var firstSource = try XCTUnwrap(sources.get(urlId: firstUrlId))
        var secondSource = try XCTUnwrap(sources.get(urlId: secondUrlId))
        XCTAssertEqual(firstSource.addedAt, before)
        XCTAssertEqual(firstSource.type, .suggestion)
        XCTAssertEqual(secondSource.addedAt, before)
        XCTAssertEqual(secondSource.type, .suggestion)

        //re-adding sources with same url overwrites info when the source is of user type
        //nothing happens when the source is of type suggesion
        sources.add(urlId: firstUrlId, type: .user, date: now)
        sources.add(urlId: secondUrlId, type: .suggestion, date: now)
        XCTAssertEqual(sources.count, 2)
        firstSource = try XCTUnwrap(sources.get(urlId: firstUrlId))
        secondSource = try XCTUnwrap(sources.get(urlId: secondUrlId))
        XCTAssertEqual(firstSource.addedAt, now)
        XCTAssertEqual(firstSource.type, .user)
        XCTAssertEqual(secondSource.addedAt, before)
        XCTAssertEqual(secondSource.type, .suggestion)
    }

    func testRemoveProtected() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        sources.add(urlId: firstUrlId, type: .user)
        sources.add(urlId: secondUrlId, type: .suggestion)

        //removing a .user added source with isUserSourceProtected
        //only removes .suggested sources
        sources.remove(urlId: firstUrlId, isUserSourceProtected: true)
        sources.remove(urlId: secondUrlId, isUserSourceProtected: true)
        _ = try XCTUnwrap(sources.get(urlId: firstUrlId))
        XCTAssertEqual(sources.count, 1)
    }

    func testRemoveUnprotected() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        sources.add(urlId: firstUrlId, type: .user)
        sources.add(urlId: secondUrlId, type: .suggestion)

        //removing with not isUserSourceProtected removes all types of sources
        sources.remove(urlId: firstUrlId, isUserSourceProtected: false)
        sources.remove(urlId: secondUrlId, isUserSourceProtected: false)
        XCTAssertEqual(sources.count, 0)
    }

    func testSourcesScoreRefresh() throws {
        let dataSet: [(String, Int?)] = [
            //url, textAddCount
            ("http://www.red.com", 1),
            ("http://www.green.com", 3),
            ("http://www.blue.com", nil),
        ]
        //At source addition, sources longTermScore objects are nil
        for row in dataSet {
            let id = LinkStore.createIdFor(row.0, title: "")
            if let selections = row.1 {
                scoreStore.apply(to: id) { $0.textSelections = selections }
            }
            sources.add(urlId: id, type: .user)
            let source = try XCTUnwrap(sources.get(urlId: id))
            XCTAssertNil(source.longTermScore)
        }
        
        //After sync, if the score exists, the longTermScores are filled
        let expectation = self.expectation(description: "Score Refresh")
        sources.refreshScores(scoreStore: scoreStore) { expectation.fulfill() }
        waitForExpectations(timeout: 1, handler: nil)

        for row in dataSet {
            let id = LinkStore.getIdFor(row.0)!
            let source = try XCTUnwrap(sources.get(urlId: id))
            if let selections = row.1 {
                let longTermScore = try XCTUnwrap(source.longTermScore)
                XCTAssertEqual(longTermScore.textSelections, selections)
            } else {
                XCTAssertNil(source.longTermScore)
            }
        }
    }

    
    func testSourceSort() throws {
        let now = Date()
        let oneDay = Double(24.0 * 60.0 * 60.0)
        let yesterday = now - oneDay
        let beforeYesterday = now - 2 * oneDay
        
        let dataSet: [(String, Int, NoteSource.SourceType, Date)] = [
            //url, textAddCount, sourceType, addDate
            ("http://www.url.com/a", 1, .suggestion, yesterday),
            ("http://www.anotherurl.com/a", 3, .user, yesterday),
            ("http://www.url.com/b", 2, .suggestion, beforeYesterday),
            ("http://www.url.com/c", 1, .user, yesterday),
        ]
        
        func indexToUrlId(index: Int) -> UInt64 {
            let url = dataSet[index].0
            return LinkStore.getIdFor(url)!
        }
        //adding note source and inserting their longTermScore counterparts in
        //db
        for row in dataSet {
            let id = LinkStore.createIdFor(row.0, title: "")
            scoreStore.apply(to: id) {
                $0.lastCreationDate = now
                $0.textSelections = row.1
            }
            sources.add(urlId: id, type: row.2, date: row.3)
        }
        //syncing note sources scores with db
        let expectation = self.expectation(description: "Score Refresh")
        sources.refreshScores(scoreStore: scoreStore) { expectation.fulfill() }
        waitForExpectations(timeout: 1, handler: nil)
        
        //sorting sources (in case of ties, user sources are shown first an then sorted by scores)
        var sortedUrlIds = sources.sortedByDomain().map { $0.urlId }
        var expectedSortedIds: [UInt64] = [1, 3, 2, 0].map(indexToUrlId)
        XCTAssertEqual(sortedUrlIds, expectedSortedIds)
        
        sortedUrlIds = sources.sortedByDomain(ascending: false).map { $0.urlId }
        expectedSortedIds = [3, 2, 0, 1].map(indexToUrlId)
        XCTAssertEqual(sortedUrlIds, expectedSortedIds)
        
        sortedUrlIds = sources.sortedByAddedDay().map { $0.urlId }
        expectedSortedIds = [2, 1, 3, 0].map(indexToUrlId)
        XCTAssertEqual(sortedUrlIds, expectedSortedIds)
        
        sortedUrlIds = sources.sortedByAddedDay(ascending: false).map { $0.urlId }
        expectedSortedIds = [1, 3, 0, 2].map(indexToUrlId)
        XCTAssertEqual(sortedUrlIds, expectedSortedIds)
        
        sortedUrlIds = sources.sortedByScoreDesc().map { $0.urlId }
        expectedSortedIds = [1, 3, 2, 0].map(indexToUrlId)
        XCTAssertEqual(sortedUrlIds, expectedSortedIds)
        }
}
