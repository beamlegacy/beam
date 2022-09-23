//
//  GRDBDailyNoteScoreStoreTests.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 25/08/2022.
//

import XCTest
@testable import Beam
@testable import BeamCore

class GRDBDailyNoteScoreStoreTests: XCTestCase {
    override func setUp() {
        KeychainDailyNoteScoreStore.shared = KeychainDailyNoteScoreStore()
    }

    func testKeyChainToGRDBMigration() throws {
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let db = GRDBStore.empty()
        let manager = try NoteStatsDBManager(store: db)
        let noteId = UUID()
        let day0 = BeamDate.now.localDayString()!
        let keychainStoreBefore = KeychainDailyNoteScoreStore.shared
        keychainStoreBefore.apply(to: noteId) { $0.lastWordCount = 3 }
        BeamDate.travel(24 * 60 * 60)
        let day1 = BeamDate.now.localDayString()!
        keychainStoreBefore.apply(to: noteId) { $0.visitCount = 5}
        try db.migrate(upTo: "createDailyNoteScoreTables")

        //data from keychain should be moved to grdb
        let record0 = try XCTUnwrap(try manager.getDailyNoteScore(noteId: noteId, localDay: day0))
        XCTAssertEqual(record0.lastWordCount, 3)
        let record1 = try XCTUnwrap(try manager.getDailyNoteScore(noteId: noteId, localDay: day1))
        XCTAssertEqual(record1.visitCount, 5)
        let keychainStoreAfter = KeychainDailyNoteScoreStore()
        XCTAssertEqual(keychainStoreAfter.notesLastWordCountChangeDay.count, 0)
        XCTAssertEqual(keychainStoreAfter.scores.count, 0)
        BeamDate.reset()
    }
    func testStoreScore() throws {
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let db = GRDBStore.empty()
        let manager = try NoteStatsDBManager(store: db)
        try db.migrate()
        let store = GRDBDailyNoteScoreStore(db: manager)

        let noteId = UUID()
        store.apply(to: noteId) { $0.visitCount = 1 }
        let scores = store.getScores(daysAgo: 0)
        let scoreFromScores = try XCTUnwrap(scores[noteId])
        XCTAssertEqual(scoreFromScores.visitCount, 1)
        let score = try XCTUnwrap(store.getScore(noteId: noteId, daysAgo: 0))
        XCTAssertEqual(score.visitCount, 1)

        store.cleanup(daysToKeep: 1)
        XCTAssertEqual(store.getScores(daysAgo: 0).count, 1)
        store.cleanup(daysToKeep: 0)
        XCTAssertEqual(store.getScores(daysAgo: 0).count, 0)

        BeamDate.reset()
    }

    func testStoreWordCountChangeDay() throws {
        BeamDate.freeze("2001-01-01T00:01:00+000")
        let db = GRDBStore.empty()
        let manager = try NoteStatsDBManager(store: db)
        try db.migrate()
        let store = GRDBDailyNoteScoreStore(db: manager)

        let noteIds = (0...2).map { _ in UUID() }
        store.recordLastWordCountChange(noteId: noteIds[0], wordCount: 1)
        store.recordLastWordCountChange(noteId: noteIds[0], wordCount: 2)

        store.recordLastWordCountChange(noteId: noteIds[1], wordCount: 1)

        BeamDate.travel(24 * 60 * 60)
        store.recordLastWordCountChange(noteId: noteIds[2], wordCount: 1)
        store.recordLastWordCountChange(noteId: noteIds[2], wordCount: 2)

        XCTAssertEqual(store.getNoteIdsLastChangedAtAndAfter(daysAgo: 1).0, [noteIds[0]])
        XCTAssertEqual(store.getNoteIdsLastChangedAtAndAfter(daysAgo: 1).1, [noteIds[2]])

        BeamDate.freeze()
    }
}
