//
//  PublishNoteAPITests.swift
//  BeamTests
//
//  Created by Ludovic Ollagnier on 24/09/2021.
//

import XCTest

@testable import Beam
@testable import BeamCore
import Atomics

class PublishNoteAPITests: XCTestCase {

    var helper: DocumentManagerTestsHelper!
    var beamTestHelper = BeamTestsHelper()
    var coreDataManager: CoreDataManager!

    var testNote: BeamNote?
    var testNoteDocumentStruct: DocumentStruct!

    override func setUpWithError() throws {
        BeamTestsHelper.logout()
        BeamDate.freeze("2022-04-18T06:00:03Z")
        beamTestHelper.beginNetworkRecording(test: self)

        LoggerRecorder.shared.reset()

        coreDataManager = CoreDataManager()
        CoreDataManager.shared = coreDataManager

        // Setup CoreData
        coreDataManager.setupWithoutMigration()

        helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                            coreDataManager: CoreDataManager.shared)

        helper.deleteAllDocuments()
        helper.deleteAllDatabases()

        helper.createDefaultDatabase()

        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

        BeamTestsHelper.login()
        testNote = BeamNote(title: "Test")
        testNote!.databaseId = DatabaseManager.defaultDatabase.id

        let testNoteDocumentStruct = testNote!.documentStruct

        self.testNoteDocumentStruct = helper.saveLocally(testNoteDocumentStruct!)

        // Consecutive saves expect both those variable to be up to date
        testNote!.version.store(self.testNoteDocumentStruct.version, ordering: .relaxed)
        testNote!.savedVersion = testNote!.version
    }

    override func tearDownWithError() throws {

        helper.deleteDocumentStruct(testNoteDocumentStruct)
        BeamTestsHelper.logout()
        beamTestHelper.endNetworkRecording()
        BeamDate.reset()
    }

    func testNotePublicationUnpublication() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        AuthenticationManager.shared.username = "Test user"

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note,
                                            becomePublic: true,
                                            completion: { result in
            switch result {
            case .success(let published):
                XCTAssertTrue(published)
            case .failure(let error):
                XCTFail("Note publication loggedIn with username should succeed :\(error)")
            }
            publish.fulfill()
        })
        waitForExpectations(timeout: 10, handler: nil)

        let pubLink = BeamNoteSharingUtils.getPublicLink(for: note)
        XCTAssertNotNil(pubLink)

        let unpublish = expectation(description: "note unpublish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, completion: { result in
            switch result {
            case .success(let published):
                XCTAssertFalse(published)
            case .failure(let error):
                XCTFail("Note publication loggedIn with username should \(error)")
            }
            unpublish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)

        let unpubLink = BeamNoteSharingUtils.getPublicLink(for: note)
        XCTAssertNil(unpubLink)
    }

    func testNotePublicationNotLogged() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        BeamTestsHelper.logout()

        XCTAssertFalse(AuthenticationManager.shared.isAuthenticated)

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, completion: { result in
            assertIsFailure(result)
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testUnpublishNotPublishedNote() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, completion: { result in
            assertIsFailure(result)
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }
}
