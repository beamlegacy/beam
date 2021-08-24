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
    private var note: BeamNote!
    
    override func setUp() {
        super.setUp()
        note = BeamNote(title: "Some research")
        sources = note.sources
        scoreStore = LongTermUrlScoreStore(db: GRDBDatabase.empty())
    }
    
    func testAdd() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        let noteId = UUID()
        let now = BeamDate.now
        let before = Date() - Double(60.0 * 60.0)
        let sessionId = UUID()
        let activeSources = ActiveSources()

        //added sources can be retreived
        sources.add(urlId: firstUrlId, noteId: noteId, type: .suggestion, date: before, sessionId: sessionId, activeSources: activeSources)
        sources.add(urlId: secondUrlId, noteId: noteId, type: .suggestion, date: before, sessionId: sessionId, activeSources: activeSources)
        XCTAssertEqual(sources.count, 2)
        var firstSource = try XCTUnwrap(sources.get(urlId: firstUrlId))
        var secondSource = try XCTUnwrap(sources.get(urlId: secondUrlId))
        XCTAssertEqual(firstSource.addedAt, before)
        XCTAssertEqual(firstSource.type, .suggestion)
        XCTAssertEqual(secondSource.addedAt, before)
        XCTAssertEqual(secondSource.type, .suggestion)

        //re-adding sources with same url overwrites info when the source is of user type
        //nothing happens when the source is of type suggesion
        sources.add(urlId: firstUrlId, noteId: noteId, type: .user, date: now, sessionId: sessionId, activeSources: activeSources)
        sources.add(urlId: secondUrlId, noteId: noteId, type: .suggestion, date: now, sessionId: sessionId, activeSources: activeSources)
        XCTAssertEqual(sources.count, 2)
        firstSource = try XCTUnwrap(sources.get(urlId: firstUrlId))
        secondSource = try XCTUnwrap(sources.get(urlId: secondUrlId))
        XCTAssertEqual(firstSource.addedAt, now)
        XCTAssertEqual(firstSource.type, .user)
        XCTAssertEqual(firstSource.sessionId, sessionId)
        XCTAssertEqual(secondSource.addedAt, before)
        XCTAssertEqual(secondSource.type, .suggestion)
        XCTAssertEqual(secondSource.sessionId, sessionId)

    }

    func testRemoveProtected() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        let noteId = UUID()
        let sessionId = UUID()
        let activeSources = ActiveSources()
        sources.add(urlId: firstUrlId, noteId: noteId, type: .user, sessionId: sessionId, activeSources: activeSources)
        sources.add(urlId: secondUrlId, noteId: noteId, type: .suggestion, sessionId: sessionId, activeSources: activeSources)

        //removing a .user added source with isUserSourceProtected
        //only removes .suggested sources
        sources.remove(urlId: firstUrlId, noteId: noteId, isUserSourceProtected: true, activeSources: activeSources)
        //it doesnt remove protected source event if sessionId matches
        sources.remove(urlId: firstUrlId, noteId: noteId, isUserSourceProtected: true, sessionId: sessionId, activeSources: activeSources)
        sources.remove(urlId: secondUrlId, noteId: noteId, isUserSourceProtected: true, activeSources: activeSources)
        _ = try XCTUnwrap(sources.get(urlId: firstUrlId))
        XCTAssertEqual(sources.count, 1)
    }

    func testRemoveUnprotected() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        let sessionId = UUID()
        let noteId = UUID()
        let activeSources = ActiveSources()
        sources.add(urlId: firstUrlId, noteId: noteId, type: .user, sessionId: sessionId, activeSources: activeSources)
        sources.add(urlId: secondUrlId, noteId: noteId, type: .suggestion, sessionId: sessionId, activeSources: activeSources)

        //removing with not isUserSourceProtected removes all types of sources
        sources.remove(urlId: firstUrlId, noteId: noteId, isUserSourceProtected: false,activeSources: activeSources)
        sources.remove(urlId: secondUrlId, noteId: noteId, isUserSourceProtected: false, activeSources: activeSources)
        XCTAssertEqual(sources.count, 0)
    }
    func testRemoveWithSessionId() throws {
        let firstUrlId: UInt64 = 0
        let secondUrlId: UInt64 = 1
        let firstSessionId = UUID()
        let secondSessionId = UUID()
        let noteId = UUID()
        let activeSources = ActiveSources()
        sources.add(urlId: firstUrlId, noteId: noteId, type: .suggestion, sessionId: firstSessionId, activeSources: activeSources)
        sources.add(urlId: secondUrlId, noteId: noteId, type: .suggestion, sessionId: secondSessionId, activeSources: activeSources)

        //only source with matching session id is removed
        sources.remove(urlId: firstUrlId, noteId: noteId, sessionId: firstSessionId, activeSources: activeSources)
        sources.remove(urlId: secondUrlId, noteId: noteId, sessionId: firstSessionId, activeSources: activeSources)
        XCTAssertEqual(sources.count, 1)
        _ = try XCTUnwrap(sources.get(urlId: secondUrlId))
    }

    func testSourcesScoreRefresh() throws {
        let dataSet: [(String, Int?)] = [
            //url, textAddCount
            ("http://www.red.com", 1),
            ("http://www.green.com", 3),
            ("http://www.blue.com", nil),
        ]
        let sessionId = UUID()
        let noteId = UUID()
        //At source addition, sources longTermScore objects are nil
        for row in dataSet {
            let id = LinkStore.createIdFor(row.0, title: "")
            if let selections = row.1 {
                scoreStore.apply(to: id) { $0.textSelections = selections }
            }
            sources.add(urlId: id, noteId: noteId, type: .user, sessionId: sessionId)
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
        let now = BeamDate.now
        let oneDay = Double(24.0 * 60.0 * 60.0)
        let yesterday = now - oneDay
        let beforeYesterday = now - 2 * oneDay
        let sessionId = UUID()
        let noteId = UUID()
        let activeSources = ActiveSources()
        
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
            sources.add(urlId: id, noteId: noteId, type: row.2, date: row.3, sessionId: sessionId, activeSources: activeSources)
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

    func testNoteChangeTrigger() throws {
        XCTAssertNil(note.changed)
        let updateDate = note.updateDate

        //adding a note source will trigger a note save
        note.sources.add(urlId: 0, noteId: note.id, type: .user, sessionId: UUID())
        let noteChangedSourceCreate = try XCTUnwrap(note.changed)
        let updateDateSourceCreate = note.updateDate
        XCTAssertEqual(noteChangedSourceCreate.1, .meta)
        XCTAssert(updateDateSourceCreate.timeIntervalSince(updateDate) > 0)

        //updating a note source will trigger a note save
        note.sources.add(urlId: 0, noteId: note.id, type: .user, sessionId: UUID())
        let noteChangedSourceUpdate = try XCTUnwrap(note.changed)
        let updateDateSourceUpdate = note.updateDate
        XCTAssertEqual(noteChangedSourceUpdate.1, .meta)
        XCTAssert(updateDateSourceUpdate.timeIntervalSince(updateDateSourceCreate) > 0)

        //deleting a note source will trigger a note save
        note.sources.remove(urlId: 0, noteId: note.id, isUserSourceProtected: false)
        let noteChangedSourceDelete = try XCTUnwrap(note.changed)
        let updateDateSourceDelete = note.updateDate
        XCTAssertEqual(noteChangedSourceDelete.1, .meta)
        XCTAssert(updateDateSourceDelete.timeIntervalSince(updateDateSourceUpdate) > 0)
    }
}
