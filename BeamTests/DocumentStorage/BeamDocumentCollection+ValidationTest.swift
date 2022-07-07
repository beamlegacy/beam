//
//  BeamDocumentCollection+ValidationTest.swift
//  BeamCoreTests
//
//  Created by Jérôme Blondon on 19/05/2022.
//

import Foundation
import XCTest
@testable import BeamCore
@testable import Beam
import GRDB

class BeamDocumentCollectionValidationTest: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    var store: GRDBStore!
    var documentCollection: BeamDocumentCollection!

    // MARK: Setup

    override func setUpWithError() throws {
        try super.setUpWithError()
        let dbPath = "file::memory:"
        let db = try DatabaseQueue(path: dbPath)
        store = GRDBStore(writer: db)
        try store.erase()
        documentCollection = try BeamDocumentCollection(holder: nil, store: store)
        try store.migrate()
    }

    override func tearDownWithError() throws {
        XCTAssertTrue(store.isEmpty)
        try store.erase()
    }

    // MARK: Tests

    func testInvalidJournalDay() throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyy-MM-dd"
        let date = formatter.date(from: "22022-01-01")
        guard let date = date else {
            XCTFail("Unable to create date")
            return
        }
        XCTAssertThrowsError(try documentCollection.fetchOrCreate(self, type: .journal(date: date)), "Journal day should be invalid")
    }

    func testDuplicateJournalDates() throws {
        let date = "2022-01-01"

        let docA = try documentCollection.fetchOrCreate(self, type: .journal(date: dateFromString(date)))
        let docB = try documentCollection.fetchOrCreate(self, type: .journal(date: dateFromString(date)))

        XCTAssertNotNil(docA)
        XCTAssertNotNil(docB)
        XCTAssertEqual(docA, docB, "Error while creating new document")

        var docC = try documentCollection.fetchOrCreate(self, type: .journal(date: dateFromString("2022-01-02")))
        XCTAssertNotNil(docC)
        XCTAssertNotEqual(docC, docA, "Error while creating new document")

        // Update doc to existing journal date
        docC.journalDate = JournalDateConverter.toInt(from: date)
        XCTAssertThrowsError(try documentCollection.save(self, docC, indexDocument: true), "Error while trying to avoid duplicates")
    }

    func testConversions() throws {
        var doc = try documentCollection.fetchOrCreate(self, type: .journal(date: dateFromString("2022-01-02")))
        XCTAssertNotNil(doc)

        // Convert journal to note
        doc.documentType = .note
        doc = try documentCollection.save(self, doc, indexDocument: true)
        XCTAssertNotNil(doc)
        XCTAssertEqual(0, doc.journalDate, "Journal date should be reset")

        // But we cannot convert it back to journal note
        // Because journalDay is invalid
        doc.documentType = .journal
        XCTAssertThrowsError(try documentCollection.save(self, doc, indexDocument: true), "Error while trying to avoid duplicates")

        // Update journalDate to allow save again
        doc.journalDate = JournalDateConverter.toInt(from: "2022-02-02")
        XCTAssertNotNil(doc)
    }

    func testEmptyTitles() throws {
        XCTAssertThrowsError(try documentCollection.fetchOrCreate(self, type: .note(title: "")))
    }

    func testDuplicateTitles() throws {
        let docA = try documentCollection.fetchOrCreate(self, type: .note(title: "note-a"))
        let docB = try documentCollection.fetchOrCreate(self, type: .note(title: "note-a"))

        XCTAssertNotNil(docA)
        XCTAssertNotNil(docB)
        XCTAssertEqual(docA, docB, "Error while creating new document")

        var docC = try documentCollection.fetchOrCreate(self, type: .note(title: "note-c"))
        XCTAssertNotNil(docC)

        docC.title = "note-a"
        XCTAssertThrowsError(try documentCollection.save(self, docC, indexDocument: true), "Error while trying to avoid duplicates")

        // Delete document: make sure we can't save a deleted document locally!
        docC.title = "note-a"
        docC.deletedAt = BeamDate.now
        XCTAssertThrowsError(try documentCollection.save(self, docC, indexDocument: true))

        // Undelete
        docC.deletedAt = nil

        // Still cannot have duplicate title
        XCTAssertThrowsError(try documentCollection.save(self, docC, indexDocument: true), "Error while trying to avoid duplicates")
    }

    func testVersions() throws {
        let docA = try documentCollection.fetchOrCreate(self, type: .note(title: "note-a"))
        XCTAssertNotNil(docA)
        XCTAssertEqual(0, docA.version, "Wrong version number")

        var updatedDocA = try documentCollection.save(self, docA, indexDocument: true)

        // updatedAt is not handled by DocumentCollection
        XCTAssertEqual(docA.updatedAt, updatedDocA.updatedAt, "updatedAt should not be updated")

        // But version is
        XCTAssertEqual(1, updatedDocA.version, "Version should have been updated")

        // And can be handled by caller too
        updatedDocA.version = 12
        updatedDocA = try documentCollection.save(self, updatedDocA, indexDocument: true)
        XCTAssertEqual(13, updatedDocA.version)

        XCTAssertEqual(0, docA.version, "Wrong version number")

        // But cannot be lower than current version
        updatedDocA.version = 11
        XCTAssertThrowsError(try documentCollection.save(self, updatedDocA, indexDocument: true), "Error while trying to avoid previous version")
    }

    // MARK: Helpers

    private func dateFromString(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: string)
        guard let date = date else {
            XCTFail("Unable to create date")
            return BeamDate.now
        }
        return date
    }
}
