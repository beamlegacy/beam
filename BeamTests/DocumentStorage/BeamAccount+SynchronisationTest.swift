//
//  BeamAccount+SynchronisationTest.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 30/06/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam

import GRDB

class BeamAccountSynchronisationTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()
    var remoteObjects: [BeamObject] = []

    override func setUp() async throws {
        BeamDate.freeze("2021-03-19T12:21:03Z")

        Configuration.beamObjectDirectCall = false
        Configuration.beamObjectOnRest = true

        await logout()
        try await setupInitialState()
    }

    override func tearDown() async throws {
        await stopNetworkTests()
        beamHelper.endNetworkRecording()
        await logout()
        Configuration.reset()
    }

    func testFirstLogin() throws {
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        try noteLinksAndRefManager.clear()

        beforeNetworkTests(login: true, logoutBefore: false)

        // we have the daily note
        guard BeamNote.fetch(journalDate: BeamDate.now) != nil else {
            XCTFail("Cannot get journal day")
            return
        }

        // and 2 frecencies
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }

        let frecencyNoteRecords = try noteLinksAndRefManager.allNoteFrecencies(updatedSince: nil)
        XCTAssertEqual(frecencyNoteRecords.count, 2, "We should have 2 note frecencies automatically created")

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }

        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
            XCTFail("Cannot fetch documents")
            return
        }

        XCTAssertEqual(allDocuments.count, 4, "We should have the 2 journals (now and the day before) and 2 notes")

    }

    func testLoginAfterSignupLater() throws {
        let expectation = self.expectation(description: "setupInitialState")
        Task {
            try await self.setupInitialState()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)

        // we have the daily note
        guard let initialJournalNote = BeamNote.fetch(journalDate: BeamDate.now) else {
            XCTFail("Cannot get journal day")
            return
        }

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }

        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
            XCTFail("Cannot fetch documents")
            return
        }

        XCTAssertEqual(allDocuments.count, 4, "We should have 2 journals from freezed date and 2 notes = 4")

        beforeNetworkTests(logoutBefore: false) // this will issue a login

        let runFullSyncExpectation = self.expectation(description: "runFullSync")
        Task {
            await self.runFullSync()
            runFullSyncExpectation.fulfill()
        }
        wait(for: [runFullSyncExpectation], timeout: 60.0)

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }

        let date = JournalDateConverter.toInt(from: "2021-03-19")
        guard let journalNotes = try currentDatabase.collection?.fetch(filters: [.type(.journal), .journalDate(date)]) else {
            XCTFail("Cannot fetch journal notes")
            return
        }
        XCTAssertEqual(journalNotes.count, 1, "We should have only one journal")

        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
            XCTFail("Cannot fetch documents")
            return
        }
        XCTAssertEqual(allDocuments.count, 4, "We should have 4 documents")

        guard let currentJournalNote = BeamNote.fetch(journalDate: BeamDate.now) else {
            XCTFail("Cannot get journal day")
            return
        }
        XCTAssertNotNil(currentJournalNote.document?.database)

        XCTAssertEqual(currentJournalNote.id, initialJournalNote.id, "The initial journal and the current journal should be equal")

        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        let frecencyNoteRecords = try noteLinksAndRefManager.allNoteFrecencies(updatedSince: nil)
        XCTAssertEqual(frecencyNoteRecords.count, 2, "We should have no more than 2 frecencies for the journal")
    }

    func testSynchronisationWithExistingData() throws {
        beforeNetworkTests()

        try BeamData.shared.reloadJournal()

        guard let initialJournal = getJournal() else {
            XCTFail("Cannot get initial journal")
            return
        }

        BeamTestsHelper.login()

        let saveAndDeleteExpectation = self.expectation(description: "reset and delete state")

        Task {
            await self.runFullSync()
            // at this step data is saved on server

            // let's reset everything on app
            await self.logout()
            saveAndDeleteExpectation.fulfill()
        }
        wait(for: [saveAndDeleteExpectation], timeout: 60.0)

        try BeamData.shared.reloadJournal()

        guard let secondJournal = getJournal() else {
            XCTFail("Cannot get second journal")
            return
        }
        XCTAssertNotNil(secondJournal.document?.database)

        // a second journal is created, different from initial
        XCTAssertNotEqual(secondJournal.id, initialJournal.id)

        // we run the full sync again to get remote data
        BeamTestsHelper.login()
        let runFullSyncExpectation = self.expectation(description: "runFullSync")
        Task {
            await self.runFullSync()
            runFullSyncExpectation.fulfill()
        }
        wait(for: [runFullSyncExpectation], timeout: 160.0)

        // and the 3rd version of journal should be the same as the initial one
        // but we cannot test here because of prerecorded ids
        // (app generates a new id on each reset but vinyl has saved another)
        guard let thirdJournal = getJournal() else {
            XCTFail("Cannot get third journal")
            return
        }
        XCTAssertNotNil(thirdJournal.document?.database)
        XCTAssertEqual(thirdJournal.title, initialJournal.title)
    }

    @MainActor
    private func logout() async {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        AppData.shared.currentAccount?.logout()
        AppDelegate.main.deleteAllLocalData()
    }

    private func beforeNetworkTests(login: Bool = true, logoutBefore: Bool = true) {
        beamHelper.disableNetworkRecording()
        BeamURLSession.shouldNotBeVinyled = true

        if logoutBefore {
            BeamTestsHelper.logout()
        }
        beamHelper.beginNetworkRecording(test: self)
        if login {
            BeamTestsHelper.login()
        }
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    @MainActor
    private func stopNetworkTests() async {
        await BeamObjectTestsHelper().deleteAll()
        BeamDate.reset()
        BeamURLSession.shouldNotBeVinyled = false
    }


    private func runFullSync() async {
        guard let currentAccount = AppData.shared.currentAccount else {
            XCTFail("Cannot get currentAccount")
            return
        }
        let beamObjectManager = BeamData.shared.objectManager
        let initialDBs = Set(currentAccount.allDatabases)
        do {
            try await beamObjectManager.syncAllFromAPI(force: true,
                                                       prepareBeforeSaveAll: {
                currentAccount.mergeAllDatabases(initialDBs: initialDBs)
            })
        } catch {
            XCTFail("Cannot synchronise: \(error)")
            print("### failed")
        }
        BeamNote.clearFetchedNotes()
    }

    @MainActor
    private func setupInitialState() async throws {
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        try noteLinksAndRefManager.clear()

        OnboardingNoteCreator.shared.createOnboardingNotes()
        try BeamData.shared.reloadJournal()
    }

    private func getJournal() -> BeamNote? {
        BeamNote.fetch(journalDate: BeamDate.now)
    }
}
