//
//  BeamNoteDocumentWrapperTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 07/04/2022.
//

import Foundation

import Foundation
import BeamCore
@testable import Beam
import XCTest

class BeamNoteDocumentWrapperTests: XCTestCase {
    func makeNote() -> BeamNote {
        let generator = FakeNoteGenerator.init(count: 1, journalRatio: 0, futureRatio: 0)
        generator.generateNotes()
        return generator.notes[0]
    }

    func testExportImportNote() {
        let note = makeNote()
        let doc = BeamNoteDocumentWrapper(note: note)
        guard let tempFile = try? TemporaryFile(creatingTempDirectoryForFilename: "testNote") else {
            XCTFail("Error getting temp file")
            return
        }
        let url = tempFile.fileURL
        XCTAssertNoThrow(try doc.write(to: url, ofType: BeamNoteDocumentWrapper.documentTypeName))

        guard let importedDoc = try? BeamNoteDocumentWrapper(fileWrapper: FileWrapper(url: url, options: .immediate)) else {
            XCTFail("Error re-reading exported BeamNote document wrapper")
            return
        }

        XCTAssertEqual(note.joinTexts, importedDoc.note?.joinTexts)
        XCTAssertNoThrow(try FileManager.default.removeItem(at: url))
    }

    func testExportImportNoteCollection() {
        var notes = [UUID: BeamNote]()
        for _ in 0..<3 {
            let note = makeNote()
            notes[note.id] = note
        }

        let doc = BeamNoteCollectionWrapper(notes: Array(notes.values))
        guard let tempFile = try? TemporaryFile(creatingTempDirectoryForFilename: "testNoteCollection") else {
            XCTFail("Error getting temp file")
            return
        }
        let url = tempFile.fileURL
        XCTAssertNoThrow(try doc.write(to: url, ofType: BeamNoteCollectionWrapper.documentTypeName))

        guard let importedDoc = try? BeamNoteCollectionWrapper(fileWrapper: FileWrapper(url: url, options: .immediate)) else {
            XCTFail("Error re-reading exported BeamNote collection wrapper")
            return
        }

        for importedDoc in importedDoc.noteDocuments {
            XCTAssertNotNil(importedDoc.note)
            guard let importedNote = importedDoc.note else {
                return
            }
            let id = importedNote.id
            guard let note = notes[id] else {
                XCTFail("Unable to find corresponding note to saved note found in collection")
                continue
            }

            XCTAssertEqual(note.joinTexts, importedNote.joinTexts)
        }
        XCTAssertNoThrow(try FileManager.default.removeItem(at: url))
    }
}
