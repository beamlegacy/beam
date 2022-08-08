//
//  BeamDocumentCollectionTest.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 11/05/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam
import GRDB

class BeamDocumentCollectionTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    var store: GRDBStore!
    var documentCollection: BeamDocumentCollection!
    var account: BeamAccount!
    var database: BeamDatabase!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dbPath = "file::memory:"
        let db = try DatabaseQueue(path: dbPath)
        store = GRDBStore(writer: db)
        try store.erase()
        account = try BeamAccount(id: UUID(), email: "test@beamapp.co", name: "testAccount", path: nil)
        database = BeamDatabase(account: account, id: UUID(), name: "testDB")
        documentCollection = try BeamDocumentCollection(holder: database, store: store)
        try store.migrate()
    }

    override func tearDownWithError() throws {
        XCTAssertTrue(store.isEmpty)
        try store.erase()
    }

    func testEmptyCollection() {
        XCTAssertEqual(0, try documentCollection.count(), "Empty collection shouldn't have any document")
    }

    func testCreateDocument() throws {
        XCTAssertEqual(0, try documentCollection.count(), "Empty collection shouldn't have any document")
        let title = "test note"
        XCTAssertNil(try documentCollection.fetchWithTitle(title))
        let doc: BeamDocument?
        doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: title)))
        XCTAssertEqual(1, try documentCollection.count())
    }

    func testCreateDocumentWithIniter() throws {
        let title = "test note"
        let alteredTitle = "altered title"
        var doc: BeamDocument?

        doc = try documentCollection.fetchOrCreate(self, type: .note(title: title), { note in
            XCTAssertNotNil(note.id)
            note.title = alteredTitle
        })
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: alteredTitle)))
        XCTAssertEqual(1, try documentCollection.count())

        doc = try documentCollection.fetchOrCreate(self, id: doc!.id, type: .note(title: doc!.title), { note in
            note.title = title
        })
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: alteredTitle)))
        XCTAssertEqual(1, try documentCollection.count())
    }

    func testCreateJournal() throws {
        let date = BeamDate.now
        let journal = try documentCollection.fetchOrCreate(self, type: .journal(date: date))
        XCTAssertNotNil(journal)
        XCTAssertEqual(journal, try documentCollection.fetchFirst(filters: [.id(journal.id)]))
    }

    func testFetchOrCreateDocument() throws {
        XCTAssertEqual(0, try documentCollection.count(), "Empty collection shouldn't have any document")
        let title = "test note"
        // Create one note (it shouldn't exist)
        let note = try documentCollection.fetchOrCreate(self, type: .note(title: title))
        XCTAssertNotNil(note)

        // Fetch it again (it has just been created)
        XCTAssertEqual(note, try documentCollection.fetchOrCreate(self, type: .note(title: title)))
        XCTAssertEqual(1, try documentCollection.count())

        let date = BeamDate.now
        // Now create a journal note
        let journal = try documentCollection.fetchOrCreate(self, type: .journal(date: date))

        XCTAssertNotNil(journal)
        XCTAssertNotEqual(journal, note)

        XCTAssertEqual(2, try documentCollection.count(), "We should have two notes, one normal titled \(title) and one journal for date \(date)")
    }

    func testUpdateDocument() throws {
        XCTAssertEqual(0, try documentCollection.count(), "Empty collection shouldn't have any document")
        let title = "test note"
        XCTAssertNil(try documentCollection.fetchWithTitle(title))
        let doc: BeamDocument?
        doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
        XCTAssertNotNil(doc)
        guard let doc = doc else { return }

        XCTAssertEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: title)))
        XCTAssertEqual(1, try documentCollection.count())

        let note = try BeamNote.instanciateNote(doc)

        XCTAssertEqual(note.title, title)
        XCTAssertFalse(note.type.isJournal)

        note.addChild(BeamElement("some new bullet point"))
        guard let newDocVersion = note.document else {
            XCTFail("Unable to create BeamDocument from BeamNote \(note)")
            return
        }
        XCTAssertNoThrow(try documentCollection.save(self, newDocVersion, indexDocument: true))
        XCTAssertNotEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: title)))
        XCTAssertEqual(1, try documentCollection.count())
    }

    func testDeleteDocument() throws {
        XCTAssertEqual(0, try documentCollection.count(), "Empty collection shouldn't have any document")
        let title = "test note"
        XCTAssertNil(try documentCollection.fetchWithTitle(title))
        let doc: BeamDocument?
        doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc, try documentCollection.fetchOrCreate(self, type: .note(title: title)))
        XCTAssertEqual(1, try documentCollection.count())

        XCTAssertNoThrow(try documentCollection.delete(self, filters: [.id(doc!.id)]))
        XCTAssertEqual(0, try documentCollection.count())
        XCTAssertNil(try documentCollection.fetchWithTitle(title))
        XCTAssertEqual(0, try documentCollection.count(filters: []))
    }

    func testTrackingAllNotes() throws {
        let title1 = "test note 1"
        let title2 = "test note 2"
        _ = try documentCollection.fetchOrCreate(self, type: .note(title: title1))

        let expectation = expectation(description: "observing_called")
        let cancellable = documentCollection.observe([], nil)
            .dropFirst()
            .sink { _ in
                // Completion
            } receiveValue: { documents in
                XCTAssertEqual(2, documents.count)
                expectation.fulfill()
            }

        _ = try documentCollection.fetchOrCreate(self, type: .note(title: title2))

        waitForExpectations(timeout: 2)

        cancellable.cancel()
    }

    func testTrackingFilteredNotes() throws {
        let title1 = "test note 1"
        let title2 = "test note 2"
        let doc1 = try documentCollection.fetchOrCreate(self, type: .note(title: title1))

        let expectation = expectation(description: "observing_called")
        let cancellable = documentCollection.observe([.id(doc1.id)], nil)
            .dropFirst()
            .sink { _ in
                // Completion
            } receiveValue: { documents in
                XCTAssertEqual(1, documents.count)
                expectation.fulfill()
            }

        _ = try documentCollection.fetchOrCreate(self, type: .note(title: title2))

        waitForExpectations(timeout: 2)

        cancellable.cancel()
    }

    func testCount() throws {
        var docs: [BeamDocument] = []
        for index in 1...10 {
            let title = "title-\(String(format: "%04d", index))"
            let doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
            XCTAssertNotNil(doc)
            docs.append(doc)
        }
        XCTAssertEqual(try documentCollection.count(filters: []), 10)
        XCTAssertEqual(try documentCollection.count(filters: [.id(docs[0].id)]), 1)
        XCTAssertEqual(try documentCollection.count(filters: [.ids([docs[0].id, docs[1].id])]), 2)
        XCTAssertEqual(try documentCollection.count(filters: [.notId(docs[0].id)]), 9)
        XCTAssertEqual(try documentCollection.count(filters: [.notIds([docs[0].id, docs[1].id])]), 8)

        XCTAssertEqual(try documentCollection.count(filters: [.title(docs[0].title)]), 1)
        XCTAssertEqual(try documentCollection.count(filters: [.title("title")]), 0)
        XCTAssertEqual(try documentCollection.count(filters: [.title("title-%")]), 0)
        XCTAssertEqual(try documentCollection.count(filters: [.title("TITLE-0004")]), 1)

        XCTAssertEqual(try documentCollection.count(filters: [.titleMatch("title-0001")]), 1)
        XCTAssertEqual(try documentCollection.count(filters: [.titleMatch("title-%")]), 10)
        XCTAssertEqual(try documentCollection.count(filters: [.titleMatch("TITLE-%")]), 10)
        XCTAssertEqual(try documentCollection.count(filters: [.titleMatch("%title%")]), 10)
        XCTAssertEqual(try documentCollection.count(filters: [.titleMatch("%0001")]), 1)
        XCTAssertNoThrow(try documentCollection.count(filters: [.titleMatch("\\")]))
    }

    func testFetchNotes() throws {
        var notes: [BeamDocument] = []

        for index in 1...10 {
            let title = "note-\(String(format: "%04d", index))"
            let doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
            notes.append(doc)
            usleep(100000) // 0.1s
        }

        try XCTContext.runActivity(named: "when sorting by updatedAt") { _ in
            XCTAssertEqual(notes, try documentCollection.fetch(filters: [], sortingKey: .updatedAt(true)))
            XCTAssertEqual(notes.reversed(), try documentCollection.fetch(filters: [], sortingKey: .updatedAt(false)))

            XCTAssertEqual(notes.map { $0.title }, try documentCollection.fetchTitles(filters: [], sortingKey: .updatedAt(true)))
            XCTAssertEqual(notes.reversed().map { $0.title }, try documentCollection.fetchTitles(filters: [], sortingKey: .updatedAt(false)))

            XCTAssertEqual(notes.map { $0.id }, try documentCollection.fetchIds(filters: [], sortingKey: .updatedAt(true)))
            XCTAssertEqual(notes.reversed().map { $0.id }, try documentCollection.fetchIds(filters: [], sortingKey: .updatedAt(false)))

        }

        try XCTContext.runActivity(named: "when sorting by title") { _ in
            XCTAssertEqual(notes, try documentCollection.fetch(filters: [], sortingKey: .title(true)))
            XCTAssertEqual(notes.reversed(), try documentCollection.fetch(filters: [], sortingKey: .title(false)))
        }

        try XCTContext.runActivity(named: "when sorting by deleted") { _ in
            XCTAssertEqual(notes, try documentCollection.fetch(filters: [], sortingKey: .updatedAt(true)))

            try documentCollection.delete(self, filters: [.id(notes[0].id)])

            var updatedNotes = notes.map { $0 }
            updatedNotes.removeFirst()

            XCTAssertEqual(updatedNotes, try documentCollection.fetch(filters: [], sortingKey: .updatedAt(true)))

            _ = try documentCollection.save(self, notes[0], indexDocument: true)
        }

        try XCTContext.runActivity(named: "when filtering by title") { _ in
            // filter by title
            XCTAssertEqual([notes[4]], try documentCollection.fetch(filters: [.title("note-0005")], sortingKey: .updatedAt(true)))

            XCTAssertEqual([], try documentCollection.fetch(filters: [.title("")], sortingKey: .updatedAt(true)))

            XCTAssertEqual([], try documentCollection.fetch(filters: [.title("unknown-note")], sortingKey: .updatedAt(true)))
        }

        try XCTContext.runActivity(named: "when filtering by titleMatch") { _ in
            XCTAssertEqual([notes[3]], try documentCollection.fetch(filters: [.titleMatch("%-0004")], sortingKey: .updatedAt(true)))

            XCTAssertEqual(notes, try documentCollection.fetch(filters: [.titleMatch("note-%")], sortingKey: .updatedAt(true)))
        }

        try XCTContext.runActivity(named: "when filtering by id") { _ in
            XCTAssertEqual([notes[3]], try documentCollection.fetch(filters: [.id(notes[3].id)]))
        }

        try XCTContext.runActivity(named: "when paginating") { _ in
            XCTAssertEqual([notes[0], notes[1]], try documentCollection.fetch(filters: [.limit(2, offset: 0)], sortingKey: .updatedAt(true)))
            XCTAssertEqual([notes[1], notes[2]], try documentCollection.fetch(filters: [.limit(2, offset: 1)], sortingKey: .updatedAt(true)))

            XCTAssertEqual([], try documentCollection.fetch(filters: [.limit(2, offset: 100)], sortingKey: .updatedAt(true)))

            XCTAssertEqual([], try documentCollection.fetch(filters: [.limit(0, offset: 0)], sortingKey: .updatedAt(true)))
        }

        try XCTContext.runActivity(named: "when filtering by updatedAt") { _ in
            XCTAssertEqual([notes[8], notes[9]], try documentCollection.fetch(filters: [.updatedSince(notes[8].updatedAt)], sortingKey: .updatedAt(true)))
        }

        try XCTContext.runActivity(named: "when filtering by updatedBetween") { _ in
            XCTAssertEqual([notes[1], notes[2]], try documentCollection.fetch(filters: [.updatedBetween(notes[1].updatedAt, notes[2].updatedAt)], sortingKey: .updatedAt(true)))
        }
    }

    func testFetchJournal() throws {
        var notes: [BeamDocument] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for index in 1...10 {
            let day = String(format: "%02d", index)
            let date = formatter.date(from: "2022-01-\(day)")
            let doc = try documentCollection.fetchOrCreate(self, type: .journal(date: date!))
            notes.append(doc)
            usleep(100000) // 0.1s
        }

        try XCTContext.runActivity(named: "when sorting by journal_day") { _ in
            XCTAssertEqual(notes, try documentCollection.fetch(filters: [], sortingKey: .journal_day(true)))
            XCTAssertEqual(notes.reversed(), try documentCollection.fetch(filters: [], sortingKey: .journal_day(false)))
        }

        try XCTContext.runActivity(named: "when sorting by journal") { _ in
            XCTAssertEqual(notes, try documentCollection.fetch(filters: [], sortingKey: .journal(true)))
            XCTAssertEqual(notes.reversed(), try documentCollection.fetch(filters: [], sortingKey: .journal(false)))
        }

        try XCTContext.runActivity(named: "when filtering by journalDate") { _ in
            let date = JournalDateConverter.toInt(from: "2022-01-02")

            XCTAssertEqual([notes[1]], try documentCollection.fetch(filters: [.journalDate(date)]))
        }
    }
}
