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

    func testSaveFetch() throws {
        //Checks that createdAt is written once at creation and that updated at each create/Update
        let db = GRDBDatabase.empty()
        let storage = GRDBNoteFrecencyStorage(db: db)

        let score = FrecencyScore(id: UUID(), lastTimestamp: BeamDate.now, lastScore: 1, sortValue: 2)
        try storage.save(score: score, paramKey: .note30d0)
        var fetchedRecord = try db.fetchOneFrecencyNote(noteId: score.id, paramKey: .note30d0)
        let createdAt0 = try XCTUnwrap(fetchedRecord?.createdAt)
        let updatedAt0 = try XCTUnwrap(fetchedRecord?.updatedAt)
        
        try storage.save(score: score, paramKey: .note30d0)
        fetchedRecord = try db.fetchOneFrecencyNote(noteId: score.id, paramKey: .note30d0)
        let createdAt1 = try XCTUnwrap(fetchedRecord?.createdAt)
        let updatedAt1 = try XCTUnwrap(fetchedRecord?.updatedAt)
        XCTAssertEqual(createdAt0, createdAt1)
        XCTAssert(updatedAt0 < updatedAt1)

    }
}
