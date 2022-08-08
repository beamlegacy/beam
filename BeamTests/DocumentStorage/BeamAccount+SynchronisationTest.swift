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

import Nimble
import GRDB

class BeamAccountSynchronisationTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    let beamHelper = BeamTestsHelper()
    let beamObjectHelper = BeamObjectTestsHelper()
    var remoteObjects: [BeamObject] = []

    override func setUpWithError() throws {
        BeamDate.freeze("2021-03-19T12:21:03Z")

        Configuration.beamObjectDirectCall = false
        Configuration.beamObjectOnRest = true

        logout()
        try setupInitialState()
    }

    override func tearDown() {
        logout()
        Configuration.reset()
    }

    func testAfterSignupLater() throws {
        // we have the daily note
        guard BeamNote.fetch(journalDate: BeamDate.now) != nil else {
            XCTFail("Cannot get journal day")
            return
        }

        // the previous daily note
        let yesterday = BeamDate.now.addingTimeInterval(-60 * 60 * 24)
        guard BeamNote.fetch(journalDate: yesterday) != nil else {
            XCTFail("Cannot get journal day")
            return
        }

        // and onboarding notes
        guard BeamNote.fetch(title: "How to beam") != nil else {
            XCTFail("Cannot get 'How to beam' note")
            return
        }
        guard BeamNote.fetch(title: "Capture") != nil else {
            XCTFail("Cannot get 'Capture")
            return
        }

        // and 2 frecencies for journal
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        let frecencyNoteRecords = try noteLinksAndRefManager.allNoteFrecencies(updatedSince: nil)
        XCTAssertEqual(frecencyNoteRecords.count, 2)
    }

    func testFirstLogin() async throws {
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        try noteLinksAndRefManager.clear()

        beforeNetworkTests()

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
        XCTAssertEqual(frecencyNoteRecords.count, 2)

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }

        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
            XCTFail("Cannot fetch documents")
            return
        }

        // 2 journals from freezed date and 2 notes = 5
        XCTAssertEqual(allDocuments.count, 4)

        await stopNetworkTests()
    }

    func testLoginAfterSignupLater() async throws {
        try setupInitialState()

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

        // 2 journals from freezed date and 2 notes = 4
        XCTAssertEqual(allDocuments.count, 4)

        beforeNetworkTests(logoutBefore: false) // this will issue a login
        runFullSync()

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }

        let date = JournalDateConverter.toInt(from: "2021-03-19")
        guard let journalNotes = try currentDatabase.collection?.fetch(filters: [.type(.journal), .journalDate(date)]) else {
            XCTFail("Cannot fetch journal notes")
            return
        }
        XCTAssertEqual(journalNotes.count, 1)

        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
            XCTFail("Cannot fetch documents")
            return
        }
        XCTAssertEqual(allDocuments.count, 4)

        guard let currentJournalNote = BeamNote.fetch(journalDate: BeamDate.now) else {
            XCTFail("Cannot get journal day")
            return
        }

        // same document id after sync from scratch
        XCTAssertEqual(currentJournalNote.id, initialJournalNote.id)

        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        let frecencyNoteRecords = try noteLinksAndRefManager.allNoteFrecencies(updatedSince: nil)
        XCTAssertEqual(frecencyNoteRecords.count, 2)

        // 4 docs, 2 frecencies, 1 private key, 4 files, 1 database = 12
//        XCTAssertEqual(fetchAllRemoteObjects().count, 12)

        await stopNetworkTests()
    }

    func testSynchronisationWithExistingData() async throws {
        beforeNetworkTests()

        XCTAssertEqual(fetchAllRemoteObjects().count, 0)

        logoutAndLogin()
        try BeamData.shared.reloadJournal()

        guard let initialJournal = getJournal() else {
            XCTFail("Cannot get initial journal")
            return
        }

        runFullSync()

        XCTAssertEqual(fetchAllRemoteObjects().count, 9)

        logoutAndLogin()
        try BeamData.shared.reloadJournal()

        guard let secondJournal = getJournal() else {
            XCTFail("Cannot get second journal")
            return
        }

        XCTAssertNotEqual(secondJournal.id, initialJournal.id)

        runFullSync()

        guard let thirdJournal = getJournal() else {
            XCTFail("Cannot get third journal")
            return
        }

        XCTAssertEqual(thirdJournal.id, initialJournal.id)

        guard let currentDatabase = BeamData.shared.currentDatabase else {
            XCTFail("Cannot get current database")
            return
        }
        guard let reloadedJournals = try currentDatabase.collection?.fetch(filters: [.ids([thirdJournal.id, initialJournal.id])])  else {
            XCTFail("Cannot fetch documents")
            return
        }

        print("Initial journal id: \(initialJournal.id)")
        print("Third journal id: \(thirdJournal.id)")

        print(reloadedJournals.map {
            "\($0.id) - \($0.title) - \(String(describing: $0.deletedAt))"
        })

//        XCTAssertEqual(fetchAllRemoteObjects().count, 12)
//
//        guard let currentDatabase = BeamData.shared.currentDatabase else {
//            XCTFail("Cannot get current database")
//            return
//        }
//
//        guard let allDocuments = try currentDatabase.collection?.fetch(filters: []) else {
//            XCTFail("Cannot fetch documents")
//            return
//        }
//
//        // 2 journals from freezed date and 2 notes = 4
//        XCTAssertEqual(allDocuments.count, 4)
//
//        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
//            XCTFail("Cannot get noteLinksAndRefsManager")
//            return
//        }
//        let frecencyNoteRecords = try noteLinksAndRefManager.allNoteFrecencies(updatedSince: nil)
//        XCTAssertEqual(frecencyNoteRecords.count, 2)
//
//        XCTAssertEqual(fetchAllRemoteObjects().count, 12)

        await stopNetworkTests()
    }

    private func logout() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        BeamData.shared.currentAccount?.logout()
        AppDelegate.main.deleteAllLocalData()
    }

    private func beforeNetworkTests(logoutBefore: Bool = true) {
        beamHelper.disableNetworkRecording()
        BeamURLSession.shouldNotBeVinyled = true

        if logoutBefore {
            BeamTestsHelper.logout()
        }
//        beamHelper.beginNetworkRecording(test: self)
        BeamTestsHelper.login()
        try? EncryptionManager.shared.replacePrivateKey(for: Configuration.testAccountEmail, with: Configuration.testPrivateKey)
    }

    private func stopNetworkTests() async {
        await BeamObjectTestsHelper().deleteAll()
//        beamHelper.endNetworkRecording()
        BeamDate.reset()
        BeamURLSession.shouldNotBeVinyled = false
    }


    private func runFullSync() {
        guard let currentAccount = BeamData.shared.currentAccount else {
            XCTFail("Cannot get currentAccount")
            return
        }
        let beamObjectManager = BeamObjectManager()
        let initialDBs = Set(currentAccount.allDatabases)
        waitUntil(timeout: .seconds(60)) { done in
            Task {
                do {
                    try await beamObjectManager.syncAllFromAPI(force: true,
                                                               prepareBeforeSaveAll: {
                        currentAccount.mergeAllDatabases(initialDBs: initialDBs)
                    })
                } catch {
                    XCTFail("Cannot synchronise: \(error)")
                }
                done()
            }
        }
    }

    private func setupInitialState() throws {
        guard let noteLinksAndRefManager = BeamData.shared.currentDatabase?.noteLinksAndRefsManager else {
            XCTFail("Cannot get noteLinksAndRefsManager")
            return
        }
        try noteLinksAndRefManager.clear()

        OnboardingNoteCreator.shared.createOnboardingNotes()
        try BeamData.shared.reloadJournal()
    }

    private func fetchAllRemoteObjects() -> [BeamObject] {
        self.remoteObjects = []
        waitUntil(timeout: .seconds(60)) { done in
            Task {
                do {
                    defer {
                        done()
                    }

                    struct Parameters: Codable {
                        let fields: String?
                        let ids: [String]?
                        let beamObjectType: String?
                        let filterDeleted: Bool?
                        let receivedAtAfter: String?
                    }
                    let fields = "id,checksum,createdAt,updatedAt,deletedAt,receivedAt,data,dataUrl,type,checksum,privateKeySignature"

                    let parameters = Parameters(
                        fields: fields,
                        ids: nil,
                        beamObjectType: nil,
                        filterDeleted: false,
                        receivedAtAfter: nil
                    )

                    let userMe: UserMe = try await BeamObjectRequest().performRestRequest(path: .fetchAll,
                                                                                          postParams: parameters,
                                                                                          authenticatedCall: true)
                    guard let beamObjects = userMe.beamObjects else {
                        XCTFail("Cannot fetch remote objects)")
                        return
                    }

                    DispatchQueue.main.sync {
                        self.remoteObjects = beamObjects
                    }
                } catch {
                    XCTFail("Cannot fetch remote objects: \(error)")
                }
            }
        }
        return self.remoteObjects
    }

    private func logoutAndLogin() {
        logout()
        BeamTestsHelper.login()
    }

    private func getJournal() -> BeamNote? {
        BeamNote.fetch(journalDate: BeamDate.now)
    }
}

