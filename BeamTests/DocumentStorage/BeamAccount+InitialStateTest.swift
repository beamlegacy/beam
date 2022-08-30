//
//  BeamAccount+InitialState.swift
//  BeamTests
//
//  Created by Jérôme Blondon on 13/07/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam

import Nimble
import GRDB

class BeamAccountInitialStateTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }

    let objectManager = BeamData.shared.objectManager

    override func setUpWithError() throws {
        BeamDate.freeze("2021-03-19T12:21:03Z")

        logout()
        try setupInitialState()
    }

    override func tearDown() {
        logout()
    }

    func testAfterSignupLater() throws {
        // we have the good number of managers
        XCTAssertEqual(objectManager.managerOrder.count, objectManager.managerInstances.count, "Wrong number of registered managers!")

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

    private func logout() {
        for window in AppDelegate.main.windows {
            window.state.closeAllTabs(closePinnedTabs: true)
        }
        AppData.shared.currentAccount?.logout()
        AppDelegate.main.deleteAllLocalData()
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
}

