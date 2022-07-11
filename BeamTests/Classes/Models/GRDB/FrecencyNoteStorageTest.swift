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

    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()
    var db: BeamNoteLinksAndRefsManager!

    override func setUpWithError() throws {
        super.setUp()

        BeamTestsHelper.logout()
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

        let store = GRDBStore.empty()
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

    func testApiSaveLimiter() throws {
        let limiter = NoteFrecencyApiSaveLimiter(saveOnApiLimit: 2)
        let ids = (0...2).map { _ in UUID() }
        let before = BeamDate.now
        let after = before + 1

        //First case: we add 2 records with same ids, after 2nd call there is 1 record to save as we deduplicate on id
        limiter.add(record: FrecencyNoteRecord(id: ids[0], noteId: UUID(), lastAccessAt: after, frecencyScore: 1, frecencySortScore: 1, frecencyKey: .note30d0))
        //Under limit, no records to save
        XCTAssertNil(limiter.recordsToSave)
        limiter.add(record: FrecencyNoteRecord(id: ids[0], noteId: UUID(), lastAccessAt: before, frecencyScore: 1, frecencySortScore: 1, frecencyKey: .note30d0))
        //Limit reached, record to save exists
        var records = try XCTUnwrap(limiter.recordsToSave)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].id, ids[0])
        XCTAssertEqual(records[0].lastAccessAt, after)
        //after accessing recordsToSave, limiter gets emptied
        XCTAssertNil(limiter.recordsToSave)

        //First case: we add 2 records with distinct ids
        limiter.add(record: FrecencyNoteRecord(id: ids[1], noteId: UUID(), lastAccessAt: after, frecencyScore: 1, frecencySortScore: 1, frecencyKey: .note30d0))
        //Under limit, no records to save
        XCTAssertNil(limiter.recordsToSave)
        limiter.add(record: FrecencyNoteRecord(id: ids[2], noteId: UUID(), lastAccessAt: after, frecencyScore: 1, frecencySortScore: 1, frecencyKey: .note30d0))
        //Limit reached, record to save exists
        records = try XCTUnwrap(limiter.recordsToSave)
        //after accessing recordsToSave, limiter gets emptied
        XCTAssertEqual(records.count, 2)
        XCTAssertNil(limiter.recordsToSave)
    }

    func testApiSaveLimiterIntegration() throws {
        //We at least check that rate limiter doesnt prevent sending on api til save limit.
        beforeNetworkTests()

        let storage = GRDBNoteFrecencyStorage(db: db)
        storage.resetApiSaveLimiter()
        let noteIds = (0..<10).map { _ in UUID() }
        var correspondingRecords = [FrecencyNoteRecord]()

        for noteId in noteIds {
            let score = FrecencyScore(id: noteId, lastTimestamp: BeamDate.now, lastScore: 1, sortValue: 2)
            try storage.save(score: score, paramKey: .note30d0)
            let correspondingRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteId, paramKey: .note30d0))
            correspondingRecords.append(correspondingRecord)
        }
        expect(storage.batchSaveOnApiCompleted).toEventually(beTrue(), timeout: .seconds(2))
        for record in correspondingRecords {
            let fetchedRecord = try self.beamObjectHelper.fetchOnAPI(record)
            XCTAssertNotNil(fetchedRecord)
        }
        stopNetworkTests()
    }

    func testReceivedDeduplication() throws {
        let noteId = UUID()
        let now = BeamDate.now
        let storage = GRDBNoteFrecencyStorage(db: db)

        let records = [
            FrecencyNoteRecord(noteId: noteId, lastAccessAt: now, frecencyScore: 1, frecencySortScore: 1, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteId, lastAccessAt: now + 1, frecencyScore: 2, frecencySortScore: 2, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteId, lastAccessAt: now, frecencyScore: 3, frecencySortScore: 3, frecencyKey: .note30d1),
        ]
        try storage.receivedObjects(records)
        let score0 = try XCTUnwrap(storage.fetchOne(id: noteId, paramKey: .note30d0))
        XCTAssertEqual(score0.lastScore, 2) //highest last access at is kept
        let score1 = try XCTUnwrap(storage.fetchOne(id: noteId, paramKey: .note30d1))
        XCTAssertEqual(score1.lastScore, 3)
    }

    func testSoftDelete() throws {
        beforeNetworkTests()
        let noteIds = [UUID(), UUID()]
        let storage = GRDBNoteFrecencyStorage(db: db)
        let now = BeamDate.now
        let records = [
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d1),
            FrecencyNoteRecord(noteId: noteIds[1], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0),
        ]
        try db.save(noteFrecencies: records)
        storage.remoteSoftDelete(noteId: noteIds[0])
        //it soft deletes locally and remotelly
        expect(storage.softDeleteCompleted).toEventually(beTrue())
        var localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d0))
        XCTAssertEqual(localRecord.deletedAt, now)
        var fetchedRecord = try self.beamObjectHelper.fetchOnAPI(localRecord)
        XCTAssertNil(fetchedRecord)

        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d1))
        XCTAssertEqual(localRecord.deletedAt, now)
        fetchedRecord = try self.beamObjectHelper.fetchOnAPI(localRecord)
        XCTAssertNil(fetchedRecord)

        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[1], paramKey: .note30d0))
        XCTAssertNil(localRecord.deletedAt)
        XCTAssertNil(try self.beamObjectHelper.fetchOnAPI(localRecord))
        stopNetworkTests()
    }

    private func beforeNetworkTests() {
        // Need to freeze date to compare objects, as `createdAt` would be different from the network stubs we get
        // back from Vinyl.
        BeamDate.freeze("2021-03-19T12:21:03Z")

        BeamTestsHelper.logout()
        beamHelper.beginNetworkRecording(test: self)
        BeamTestsHelper.login()
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    private func stopNetworkTests() {
        BeamObjectTestsHelper().deleteAll()
        beamHelper.endNetworkRecording()
        BeamDate.reset()
    }
}
