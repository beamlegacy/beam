//
//  FrecencyNoteRecordTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 27/07/2021.
//

import XCTest
@testable import Beam

class FrecencyNoteRecordTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRecord() throws {
        let db = GRDBDatabase.empty()
        let noteIds = Array((0..<2).map { _ in UUID() })
        let ids = Array((0..<3).map { _ in UUID() })
        let records = [
            FrecencyNoteRecord(id: ids[0], noteId: noteIds[0], lastAccessAt: Date(), frecencyScore: 1.0, frecencySortScore: 1.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: ids[0], noteId: noteIds[0], lastAccessAt: Date(), frecencyScore: 2.0, frecencySortScore: 2.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: ids[1], noteId: noteIds[1], lastAccessAt: Date(), frecencyScore: 3.0, frecencySortScore: 3.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: ids[2], noteId: noteIds[0], lastAccessAt: Date(), frecencyScore: 4.0, frecencySortScore: 4.5, frecencyKey: .note30d1)
        ]
        //First record is saved an can be fetched
        try db.saveFrecencyNote(records[0])
        var fetchedRecord = try XCTUnwrap(try? db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d0))
        XCTAssertEqual(fetchedRecord.frecencyScore, 1.0)
        try db.dbReader.read { db in
            try XCTAssertEqual(FrecencyNoteRecord.fetchCount(db), 1)
        }
        for record in records[1..<4] {
            try db.saveFrecencyNote(record)
        }
        try db.dbReader.read { db in
            try XCTAssertEqual(FrecencyNoteRecord.fetchCount(db), 3)
        }
        //First record get overwritten thanks to primary key
        fetchedRecord = try XCTUnwrap(try? db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d0))
        XCTAssertEqual(fetchedRecord.frecencyScore, 2.0)
        //Inserting record sharing same primary key subcomponents as first record doesn't lead to overwritting
        fetchedRecord = try XCTUnwrap(try? db.fetchOneFrecencyNote(noteId: noteIds[1], paramKey: .note30d0))
        XCTAssertEqual(fetchedRecord.frecencyScore, 3.0)
        fetchedRecord = try XCTUnwrap(try? db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d1))
        XCTAssertEqual(fetchedRecord.frecencyScore, 4.0)

        //Fetching many sorting scores
        //Fetching nothing works
        XCTAssertEqual(db.getFrecencyScoreValues(noteIds: [], paramKey: .note30d0).count, 0)

        //Fetching under one param key
        var fetchedScores = db.getFrecencyScoreValues(noteIds: noteIds, paramKey: .note30d0)
        XCTAssertEqual(fetchedScores.count, 2)
        XCTAssertEqual(fetchedScores[noteIds[0]]?.frecencySortScore, 2.5)
        XCTAssertEqual(fetchedScores[noteIds[1]]?.frecencySortScore, 3.5)

        //Fetching under another one
        fetchedScores = db.getFrecencyScoreValues(noteIds: noteIds, paramKey: .note30d1)
        XCTAssertEqual(fetchedScores[noteIds[0]]?.frecencySortScore, 4.5)
    }
    func testFetchTopRecords() throws {
        let db = GRDBDatabase.empty()
        let noteIds = Array((0..<3).map { _ in UUID() })
        let records = [
            FrecencyNoteRecord(id: UUID(), noteId: noteIds[0], lastAccessAt: Date(), frecencyScore: 1.0, frecencySortScore: 1.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: UUID(), noteId: noteIds[1], lastAccessAt: Date(), frecencyScore: 3.0, frecencySortScore: 3.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: UUID(), noteId: noteIds[2], lastAccessAt: Date(), frecencyScore: 2.0, frecencySortScore: 2.5, frecencyKey: .note30d0),
            FrecencyNoteRecord(id: UUID(), noteId: noteIds[0], lastAccessAt: Date(), frecencyScore: 4.0, frecencySortScore: 4.5, frecencyKey: .note30d1)
        ]
        for record in records {
            try db.saveFrecencyNote(record)
        }
        let topScores = db.getTopNoteFrecencies(limit: 2, paramKey: .note30d0)
        XCTAssertEqual(topScores.count, 2)
        XCTAssertEqual(topScores[noteIds[1]]?.frecencySortScore, 3.5)
        XCTAssertEqual(topScores[noteIds[2]]?.frecencySortScore, 2.5)

    }
}
