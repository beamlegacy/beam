//
//  PinNoteTests.swift
//  BeamTests
//
//  Created by Ludovic Ollagnier on 08/06/2022.
//

import XCTest
import BeamCore
@testable import Beam

class PinNoteTests: XCTestCase {

    func testPinNote() {
        let note = BeamNote(title: "Note 1")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 1)
        XCTAssertTrue(pinnedManager.pinnedNotes.first == note)
    }

    func testUnpinNote() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 2)

        pinnedManager.unpin(notes: [note1])
        XCTAssertTrue(pinnedManager.pinnedNotes.count == 1)
        XCTAssertTrue(pinnedManager.pinnedNotes.first == note2)
    }

    func testPinMultipleNotes() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2, note3, note4])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 4)
        XCTAssertTrue(pinnedManager.pinnedNotes.first == note1)
        XCTAssertTrue(pinnedManager.pinnedNotes.last == note4)
    }

    func testPersistence() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        let toPin = [note1, note2, note3, note4]
        pinnedManager.pin(notes: toPin)

        guard let persisted = Persistence.PinnedNotes.pinnedNotesId else {
            XCTFail("No persisted IDs")
            return
        }
        XCTAssertTrue(persisted.count == 4)
        let ids = toPin.map({ $0.id.uuidString })
        XCTAssertEqual(ids, persisted)

        pinnedManager.unpinAll()
        XCTAssertTrue(Persistence.PinnedNotes.pinnedNotesId?.count == 0)
    }

    func testUnpinMultipleNotes() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2, note3, note4])

        pinnedManager.unpin(notes: [note1, note4])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 2)
        XCTAssertTrue(pinnedManager.pinnedNotes.first == note2)
        XCTAssertTrue(pinnedManager.pinnedNotes.last == note3)
    }

    func testAvoidIdenticalNotes() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2, note3, note4, note3])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 4)
        XCTAssertTrue(pinnedManager.pinnedNotes.first == note1)
        XCTAssertTrue(pinnedManager.pinnedNotes.last == note4)
    }

    func testMax5NotesIfNoSidebar() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let note5 = BeamNote(title: "Note 5")
        let note6 = BeamNote(title: "Note 6")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2, note3, note4, note5])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 5)

        pinnedManager.pin(notes: [note6])

        XCTAssertTrue(pinnedManager.pinnedNotes.count == 5)
    }

    func testCleanAll() {
        let note1 = BeamNote(title: "Note 1")
        let note2 = BeamNote(title: "Note 2")
        let note3 = BeamNote(title: "Note 3")
        let note4 = BeamNote(title: "Note 4")
        let pinnedManager = PinnedNotesManager(with: DocumentManager())

        pinnedManager.pin(notes: [note1, note2, note3, note3, note4])
        pinnedManager.unpinAll()

        XCTAssertTrue(pinnedManager.pinnedNotes.isEmpty)
    }
}
