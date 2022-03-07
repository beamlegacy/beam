//
//  DocumentManagerReceiveObjectTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 19/02/2022.
//

import XCTest
@testable import BeamCore
@testable import Beam

class DocumentManagerReceiveObjectTests: XCTestCase {
    let beamHelper = BeamTestsHelper()
    func clearNotes() {
        let documentManager = DocumentManager()
        let semaphore = DispatchSemaphore(value: 0)
        documentManager.deleteAll { result in
            switch result {
            case let .failure(error):
                Logger.shared.logError("Unable to delete all notes from DB: \(error)", category: .document)
            case let .success(res):
                if !res {
                    Logger.shared.logError("Unable to delete all notes from DB", category: .document)
                }
            }
            semaphore.signal()
        }
        XCTAssertEqual(.success, semaphore.wait(timeout: .now().advanced(by: .seconds(5))))
    }

    override func setUpWithError() throws {
        BeamObjectManager.clearNetworkCalls()
        BeamTestsHelper.logout()

        clearNotes()
    }

    override func tearDownWithError() throws {
        BeamObjectManager.clearNetworkCalls()
        clearNotes()
    }

    // MARK: receiveDeletedDocuments
    func testReceiveDeletedDocuments() throws {
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let remote = BeamNote(title: "MyNote")
        remote.addChild(BeamElement("Some text on the remote version"))
        XCTAssertEqual(remote.children.count, 1)
        var remoteStruct = try XCTUnwrap(remote.documentStruct)
        remoteStruct.deletedAt = BeamDate.now
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 0)
        XCTAssertNil(BeamNote.fetch(title: "MyNote"))
    }

    func testReceiveDeletedDocuments_conflicts() throws {
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let local = BeamNote(title: "MyNote")
        local.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(local.children.count, 1)
        let localStruct = try XCTUnwrap(local.documentStruct)
        var remoteStruct = try XCTUnwrap(local.documentStruct)
        remoteStruct.deletedAt = BeamDate.now
        XCTAssertNoThrow(try documentManager.receivedObjects([localStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 0)
        XCTAssertNil(BeamNote.fetch(title: "MyNote"))
    }

    // MARK: receiveConflictingLoadedDocument TODO
    func testReceiveConflictingLoadedDocument() throws {
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let local = BeamNote.fetchOrCreate(title: "MyNote")
        local.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(local.children.count, 1)
        XCTAssertTrue(local.syncedSave())
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)

        var remoteStruct = try XCTUnwrap(local.documentStruct)
        remoteStruct.title = "MyNote with a changed name"
        remoteStruct.updatedAt = BeamDate.now
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 1)
        let note1 = try XCTUnwrap(BeamNote.fetch(title: "MyNote with a changed name"))
        XCTAssertEqual(note1.children.count, 1)
        XCTAssertEqual(note1.joinTexts, BeamText("Some text on the local version"))
        XCTAssertNil(BeamNote.fetch(title: "MyNote"))
    }

    // MARK: receiveConflictingLoadedJournal
    func testReceiveConflictingLoadedJournal() throws {
        let date = BeamDate.now
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let localToday = BeamNote.fetchOrCreateJournalNote(date: date)
        localToday.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(localToday.children.count, 1)
        _ = localToday.syncedSave()
        let remoteToday = BeamNote(journalDate: date)
        remoteToday.addChild(BeamElement("Some text on the remote version"))
        XCTAssertEqual(remoteToday.children.count, 1)
        let remoteTodayStruct = try XCTUnwrap(remoteToday.documentStruct)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteTodayStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 2)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 1)
        let todayNote = try XCTUnwrap(BeamNote.fetch(journalDate: date))
        XCTAssertEqual(todayNote.children.count, 2)
        XCTAssertEqual(todayNote.joinTexts, BeamText("Some text on the remote versionSome text on the local version"))
    }


    // MARK: receiveConflictingJournal
    func testReceiveConflictingJournal() throws {
        let date = BeamDate.now
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let localToday = BeamNote(journalDate: date)
        localToday.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(localToday.children.count, 1)
        let localTodayStruct = try XCTUnwrap(localToday.documentStruct)
        let remoteToday = BeamNote(journalDate: date)
        remoteToday.addChild(BeamElement("Some text on the remote version"))
        XCTAssertEqual(remoteToday.children.count, 1)
        let remoteTodayStruct = try XCTUnwrap(remoteToday.documentStruct)
        XCTAssertNoThrow(try documentManager.receivedObjects([localTodayStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteTodayStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 2)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 1)
        let todayNote = try XCTUnwrap(BeamNote.fetch(journalDate: date))
        XCTAssertEqual(todayNote.children.count, 2)
        XCTAssertEqual(todayNote.joinTexts, BeamText("Some text on the remote versionSome text on the local version"))
    }

    // MARK: receiveConflictingTitleLoadedDocument
    func testReceiveConflictingTitleLoadedDocument() throws {
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let local = BeamNote.fetchOrCreate(title: "MyNote")
        local.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(local.children.count, 1)
        XCTAssertTrue(local.syncedSave())
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)

        let remote = BeamNote(title: "MyNote")
        remote.addChild(BeamElement("Some text on the remote version"))
        XCTAssertEqual(remote.children.count, 1)
        let remoteStruct = try XCTUnwrap(remote.documentStruct)
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 2)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 2)
        let note1 = try XCTUnwrap(BeamNote.fetch(title: "MyNote"))
        XCTAssertEqual(note1.id, remote.id)
        XCTAssertEqual(note1.children.count, 1)
        XCTAssertEqual(note1.joinTexts, BeamText("Some text on the remote version"))
        let note2 = try XCTUnwrap(BeamNote.fetch(title: "MyNote (2)"))
        XCTAssertEqual(note2.id, local.id)
        XCTAssertEqual(note2.children.count, 1)
        XCTAssertEqual(note2.joinTexts, BeamText("Some text on the local version"))
    }

    // MARK: receiveConflictingTitleDocument
    func testReceiveConflictingTitleDocument() throws {
        let documentManager = DocumentManager()
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 0)
        let local = BeamNote(title: "MyNote")
        local.addChild(BeamElement("Some text on the local version"))
        XCTAssertEqual(local.children.count, 1)
        let localStruct = try XCTUnwrap(local.documentStruct)
        let remote = BeamNote(title: "MyNote")
        remote.addChild(BeamElement("Some text on the remote version"))
        XCTAssertEqual(remote.children.count, 1)
        let remoteStruct = try XCTUnwrap(remote.documentStruct)
        XCTAssertNoThrow(try documentManager.receivedObjects([localStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 1)
        XCTAssertNoThrow(try documentManager.receivedObjects([remoteStruct]))
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: true).count, 2)
        XCTAssertEqual(documentManager.allDocumentsIds(includeDeletedNotes: false).count, 2)
        let note1 = try XCTUnwrap(BeamNote.fetch(title: "MyNote"))
        XCTAssertEqual(note1.id, remote.id)
        XCTAssertEqual(note1.children.count, 1)
        XCTAssertEqual(note1.joinTexts, BeamText("Some text on the remote version"))
        let note2 = try XCTUnwrap(BeamNote.fetch(title: "MyNote (2)"))
        XCTAssertEqual(note2.id, local.id)
        XCTAssertEqual(note2.children.count, 1)
        XCTAssertEqual(note2.joinTexts, BeamText("Some text on the local version"))
    }
}
