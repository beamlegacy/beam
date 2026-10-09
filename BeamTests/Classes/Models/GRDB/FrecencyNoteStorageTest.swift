//
//  FrecencyNoteStorageTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 29/12/2021.
//

import XCTest
import Nimble
@testable import BeamCore
@testable import Beam

class FrecencyNoteStorageTest: XCTestCase {

    var db: BeamNoteLinksAndRefsManager!

    override func setUpWithError() throws {
        super.setUp()

        let store = try GRDBStore.empty()
        db = try BeamNoteLinksAndRefsManager(store: store)
        try store.migrate()
    }

    func testSaveFetch() throws {
        //Checks that createdAt is written once at creation and then updated at each create/Update
        BeamDate.freeze("2001-01-01T00:00:00+000")

        let storage = GRDBNoteFrecencyStorage(db: db)

        let score = FrecencyScore(id: UUID(), lastTimestamp: BeamDate.now, lastScore: 1, sortValue: 2)
        try storage.save(score: score, paramKey: .note30d0)
        var fetchedRecord = try db.fetchOneFrecencyNote(noteId: score.id, paramKey: .note30d0)
        let createdAt0 = try XCTUnwrap(fetchedRecord?.createdAt)
        let updatedAt0 = try XCTUnwrap(fetchedRecord?.updatedAt)

        BeamDate.travel(1)

        try storage.save(score: score, paramKey: .note30d0)
        fetchedRecord = try db.fetchOneFrecencyNote(noteId: score.id, paramKey: .note30d0)
        let createdAt1 = try XCTUnwrap(fetchedRecord?.createdAt)
        let updatedAt1 = try XCTUnwrap(fetchedRecord?.updatedAt)
        XCTAssertEqual(createdAt0, createdAt1)
        XCTAssert(updatedAt0 < updatedAt1)

        BeamDate.reset()
    }

    func testSoftDelete() throws {
        BeamDate.freeze("2021-03-19T12:21:03Z")
        defer { BeamDate.reset() }
        let noteIds = [UUID(), UUID()]
        let storage = GRDBNoteFrecencyStorage(db: db)
        let now = BeamDate.now
        let records = [
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d1),
            FrecencyNoteRecord(noteId: noteIds[1], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0)
        ]
        try db.save(noteFrecencies: records)

        storage.softDelete(noteId: noteIds[0])

        var localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d0))
        XCTAssertEqual(localRecord.deletedAt, now)
        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d1))
        XCTAssertEqual(localRecord.deletedAt, now)
        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[1], paramKey: .note30d0))
        XCTAssertNil(localRecord.deletedAt)
    }
}
