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

class PublishNoteAPITests: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "PublishNoteAPITests" }

    var beamTestHelper = BeamTestsHelper()
    var coreDataManager: CoreDataManager!

    var testNote: BeamNote?
    var testNoteDocument: BeamDocument!

    let objectManager = BeamData.shared.objectManager
    let fileManager = BeamData.shared.fileDBManager!

    override func setUpWithError() throws {
        AppData.shared.currentAccount?.logout() // will force clean up data

        BeamTestsHelper.logout()
        BeamDate.freeze("2022-04-18T06:00:03Z")
        APIRequest.networkCallFiles = []
        beamTestHelper.beginNetworkRecording(test: self)
        objectManager.disableSendingObjects = true

        LoggerRecorder.shared.reset()

        coreDataManager = CoreDataManager()
        CoreDataManager.shared = coreDataManager

        // Setup CoreData
        coreDataManager.setupWithoutMigration()

        try AppData.shared.clearAllAccountsAndSetupDefaultAccount()

        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)

        BeamTestsHelper.login()
        testNote = try BeamNote(title: "Test")
        testNote?.owner = BeamData.shared.currentDatabase

        let testNoteDocument = testNote!.document

        self.testNoteDocument = try BeamData.shared.currentDocumentCollection?.save(self, testNoteDocument!, indexDocument: false, autoIncrementVersion: true)

        // Consecutive saves expect both those variable to be up to date
        testNote!.version = self.testNoteDocument.version
    }

    override func tearDownWithError() throws {
        try BeamData.shared.currentDocumentCollection?.delete(self, filters: [.id(testNoteDocument.id)])
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
                                            fileManager: fileManager,
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
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, fileManager: fileManager, completion: { result in
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

    func testNotePublicationUpdatePublicationGroupUnpublication() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        AuthenticationManager.shared.username = "Test user"

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note,
                                            becomePublic: true, fileManager: fileManager,
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

        let publicationGroupUpdatedToProfile = expectation(description: "note publication group updated")
        let profilePublicationGroups = ["profile"]
        BeamNoteSharingUtils.updatePublicationGroup(note, publicationGroups: profilePublicationGroups, fileManager: fileManager) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                print(error)
                XCTFail("\(error)")

            }
            publicationGroupUpdatedToProfile.fulfill()
        }
        waitForExpectations(timeout: 20, handler: nil)

        let publicationGroupUpdatedToEmpty = expectation(description: "note publication group updated")
        let emptyPublicationGroups: [String] = []
        BeamNoteSharingUtils.updatePublicationGroup(note, publicationGroups: emptyPublicationGroups, fileManager: fileManager) { result in
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let error):
                print(error)
                XCTFail("\(error)")

            }
            publicationGroupUpdatedToEmpty.fulfill()
        }
        waitForExpectations(timeout: 20, handler: nil)

        let unpublish = expectation(description: "note unpublish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, fileManager: fileManager, completion: { result in
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
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, fileManager: fileManager, completion: { result in
            assertIsFailure(result)
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testUnpublishNotPublishedNote() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, fileManager: fileManager, completion: { result in
            assertIsFailure(result)
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }
}
