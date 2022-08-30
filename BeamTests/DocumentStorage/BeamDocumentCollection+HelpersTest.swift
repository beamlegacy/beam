//
//  BeamDocumentCollection+HelpersTest.swift
//  BeamCoreTests
//
//  Created by Jérôme Blondon on 18/05/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam
import GRDB

class BeamDocumentCollectionHelpersTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    let objectManager = BeamObjectManager()
    var store: GRDBStore!
    var documentCollection: BeamDocumentCollection!

    var notes: [BeamDocument] = []
    var journalNotes: [BeamDocument] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dbPath = "file::memory:"
        let db = try DatabaseQueue(path: dbPath)
        store = GRDBStore(writer: db)
        try store.erase()
        documentCollection = try BeamDocumentCollection(holder: nil, objectManager: objectManager, store: store)
        try store.migrate()

        for index in 1...10 {
            let title = "note-\(String(format: "%04d", index))"
            let doc = try documentCollection.fetchOrCreate(self, type: .note(title: title))
            notes.append(doc)
            usleep(100000) // 0.1s
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for index in 1...10 {
            let day = String(format: "%02d", index + 1)
            let date = formatter.date(from: "2022-01-\(day)")
            let doc = try documentCollection.fetchOrCreate(self, type: .journal(date: date!))
            journalNotes.append(doc)
            usleep(100000) // 0.1s
        }

    }

    override func tearDownWithError() throws {
        XCTAssertTrue(store.isEmpty)
        try store.erase()
    }

    func testFetchExists() {
        XCTAssertTrue(try documentCollection.fetchExists(filters: []), "The collection should not be empty")

        XCTAssertFalse(try documentCollection.fetchExists(filters: [.id(UUID())]))

        XCTAssertTrue(try documentCollection.fetchExists(filters: [.id(notes[0].id)]))
        XCTAssertTrue(try documentCollection.fetchExists(filters: [.id(journalNotes[0].id)]))
    }

    func testFetchFirst() throws {
        XCTAssertEqual(notes[0], try documentCollection.fetchFirst(filters: [], sortingKey: .updatedAt(true)))
        XCTAssertEqual(journalNotes[9], try documentCollection.fetchFirst(filters: [], sortingKey: .updatedAt(false)))

        XCTAssertEqual(notes[0], try documentCollection.fetchFirst(filters: [.type(.note)], sortingKey: .title(true)))
        XCTAssertEqual(journalNotes[9], try documentCollection.fetchFirst(filters: [], sortingKey: .updatedAt(false)))
    }
}
