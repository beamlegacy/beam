//
//  PublicServerTests.swift
//  BeamTests
//
//  Created by Ludovic Ollagnier on 24/09/2021.
//

import XCTest

@testable import Beam
@testable import BeamCore

class PublicServerTests: XCTestCase {

    var helper: DocumentManagerTestsHelper!

    var testNote: BeamNote?
    var testNoteDocumentStruct: DocumentStruct!

    override func setUpWithError() throws {

        BeamTestsHelper.logout()
        BeamTestsHelper().beginNetworkRecording(test: self)

        helper = DocumentManagerTestsHelper(documentManager: DocumentManager(),
                                            coreDataManager: CoreDataManager.shared)

        helper.deleteAllDocuments()
        helper.deleteAllDatabases()

        helper.createDefaultDatabase()

        try? EncryptionManager.shared.replacePrivateKey(Configuration.testPrivateKey)

        BeamTestsHelper.login()
        testNote = BeamNote(title: "Test")
        testNote!.databaseId = DatabaseManager.defaultDatabase.id

        let testNoteDocumentStruct = testNote!.documentStruct

        self.testNoteDocumentStruct = helper.saveLocally(testNoteDocumentStruct!)
//        testNote!.save(documentManager: helper.documentManager)
    }

    override func tearDownWithError() throws {

        helper.deleteDocumentStruct(testNoteDocumentStruct)
        BeamTestsHelper.logout()
        BeamTestsHelper().endNetworkRecording()
    }

    func testNotePublicationUnpublicationWithUsername() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        Persistence.Authentication.username = "Test user"

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, documentManager: helper.documentManager, completion: { result in
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
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, documentManager: helper.documentManager, completion: { result in
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

    func testNotePublicationUnpublicationWithoutUsernameFallbackEmail() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        Persistence.Authentication.username = nil

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, documentManager: helper.documentManager, completion: { result in
            switch result {
            case .success(let published):
                XCTAssertTrue(published)
            case .failure(let error):
                XCTFail("Note publication loggedIn with username should succeed: \(error)")
            }
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)

        let pubLink = BeamNoteSharingUtils.getPublicLink(for: note)
        XCTAssertNotNil(pubLink)

        let unpublish = expectation(description: "note unpublish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, documentManager: helper.documentManager, completion: { result in
            switch result {
            case .success(let published):
                XCTAssertFalse(published)
            case .failure(let error):
                XCTFail("Note publication loggedIn with username should succeed: \(error)")
            }
            unpublish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)

        let unpubLink = BeamNoteSharingUtils.getPublicLink(for: note)
        XCTAssertNil(unpubLink)
    }

    func testNotePublicationUnpublicationWithoutUsernameWithoutEmail() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        Persistence.Authentication.username = nil
        Persistence.Authentication.email = nil

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, documentManager: helper.documentManager, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Note publication logged out is impossible")
            case .failure(let error):
                XCTAssertEqual(error as! BeamNoteSharingUtilsError, BeamNoteSharingUtilsError.userNotLoggedIn)
            }
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)

        let pubLink = BeamNoteSharingUtils.getPublicLink(for: note)
        XCTAssertNil(pubLink)
    }

    func testNotePublicationNotLogged() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        BeamTestsHelper.logout()

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: true, documentManager: helper.documentManager, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Note publication logged out is impossible")
            case .failure(let error):
                XCTAssertEqual(error as! BeamNoteSharingUtilsError, BeamNoteSharingUtilsError.userNotLoggedIn)
            }
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }

    func testUnpublishNotPublishedNote() {

        guard let note = testNote else { fatalError("We should have a test note in setUp") }

        let publish = expectation(description: "note publish")
        BeamNoteSharingUtils.makeNotePublic(note, becomePublic: false, documentManager: helper.documentManager, completion: { result in
            switch result {
            case .success(_):
                XCTFail("Note publication logged out is impossible")
            case .failure(let error):
                XCTAssertEqual(error as! PublicServerError, PublicServerError.notFound)
            }
            publish.fulfill()
        })
        waitForExpectations(timeout: 20, handler: nil)
    }
}
