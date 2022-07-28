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
}

class FrecencyNoteStorageWithNetworkTest: XCTestCase {

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
        BeamObjectManager.disableSendingObjects = false
        Configuration.beamObjectDirectCall = false
        beforeNetworkTests()

    }

    override func tearDown() async throws {
        await stopNetworkTests()
        await MainActor.run {
            Configuration.reset()
        }
    }

    func testApiSaveLimiterIntegration() throws {
        //We at least check that rate limiter doesnt prevent sending on api til save limit.
        let storage = GRDBNoteFrecencyStorage(db: db)
        storage.resetApiSaveLimiter()
        let noteIds = ["DFD2D24E-89C6-4B01-9386-2050B6D34257", "BD278D35-40D1-4C83-9C6F-6AA672B3FA9B", "D0ADB50E-7345-4154-888C-E1A1297CBF48", "A640B420-8AF3-4CAE-AE06-9686E222C785", "0EB709BF-BF5D-4F5F-A529-17300E70D78D", "6709F6C4-AC3A-4F0A-AF3E-3EE10AFE1FF0", "49BF4022-CBD2-4616-9013-425145D1A767", "1635FB36-2255-4967-A1F4-04680E8CEBFD", "FE311DF4-2062-41CC-896A-6404E0A59DC9", "9216D178-C6D9-4D56-9BFC-2FE55F8B18A5"].map {try! UUID(value: $0)}
        var correspondingRecords = [FrecencyNoteRecord]()
        print("testApiSaveLimiterIntegration \(noteIds)")
        for noteId in noteIds {
            // This save is required to fix FrecencyNoteRecord.id between runs
            try db.saveFrecencyNote(FrecencyNoteRecord(id: noteId, noteId: noteId, lastAccessAt: BeamDate.now, frecencyScore: 1, frecencySortScore: 2, frecencyKey: .note30d0))
            let score = FrecencyScore(id: noteId, lastTimestamp: BeamDate.now, lastScore: 1, sortValue: 2)
            try storage.save(score: score, paramKey: .note30d0)
            let correspondingRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteId, paramKey: .note30d0))
            correspondingRecords.append(correspondingRecord)
        }
        expect(storage.batchSaveOnApiCompleted).toEventually(beTrue(), timeout: .seconds(2))

        let records = correspondingRecords
        waitUntil(timeout: .seconds(10)) { done in
            DispatchQueue(label: "tests.testApiSaveLimiterIntegration").async {
                Task {
                    for record in records {
                        do {
                            let fetchedRecord = try await self.beamObjectHelper.fetchOnAPI(record)
                            XCTAssertNotNil(fetchedRecord)
                        } catch {
                            XCTFail(error.localizedDescription)
                        }
                    }
                    done()
                }
            }
        }
    }

    @MainActor
    func testSoftDelete() async throws {
        let noteIds = [UUID(), UUID()]
        let storage = GRDBNoteFrecencyStorage(db: db)
        let now = BeamDate.now
        let records = [
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d1),
            FrecencyNoteRecord(noteId: noteIds[1], lastAccessAt: BeamDate.now, frecencyScore: 0, frecencySortScore: 0, frecencyKey: .note30d0),
        ]
        try db.save(noteFrecencies: records)
        await remoteSoftDelete(storage, noteIds[0])
        //it soft deletes locally and remotelly
        XCTAssertTrue(storage.softDeleteCompleted)

        var localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d0))
        XCTAssertEqual(localRecord.deletedAt, now)
        var fetchedRecord = try await self.beamObjectHelper.fetchOnAPI(localRecord)
        XCTAssertNil(fetchedRecord)

        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[0], paramKey: .note30d1))
        XCTAssertEqual(localRecord.deletedAt, now)
        fetchedRecord = try await self.beamObjectHelper.fetchOnAPI(localRecord)
        XCTAssertNil(fetchedRecord)

        localRecord = try XCTUnwrap(try db.fetchOneFrecencyNote(noteId: noteIds[1], paramKey: .note30d0))
        XCTAssertNil(localRecord.deletedAt)
        let res = try await self.beamObjectHelper.fetchOnAPI(localRecord)
        XCTAssertNil(res)
    }

    private func remoteSoftDelete(_ storage: GRDBNoteFrecencyStorage, _ id: UUID) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue(label: "tests.remoteSoftDelete").async {
                storage.remoteSoftDelete(noteId: id) {
                    continuation.resume()
                }
            }
        }
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

    private func stopNetworkTests() async {
        await BeamObjectTestsHelper().deleteAll()
        beamHelper.endNetworkRecording()
        BeamDate.reset()
    }
}
