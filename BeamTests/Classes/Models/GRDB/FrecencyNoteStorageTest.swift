//
//  FrecencyNoteStorageTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 29/12/2021.
//

import XCTest
@testable import BeamCore
@testable import Beam

class FrecencyNoteStorageTest: XCTestCase {
    override func setUp() {
        super.setUp()
        try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)
    }

    func testSaveFetch() throws {
        //Checks that createdAt is written once at creation and then updated at each create/Update
        BeamDate.freeze("2001-01-01T00:00:00+000")

        let db = GRDBDatabase.empty()
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
}
