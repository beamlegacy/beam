//
//  NoteIndexingTests.swift
//  BeamTests
//
//  Created by Sebastien Metrot on 25/08/2021.
//

import XCTest
import Nimble
import Foundation
import Combine
@testable import BeamCore
@testable import Beam

class noteIndexingTests: XCTestCase {
    let documentManager = DocumentManager()
    override func setUpWithError() throws {
        documentManager.deleteAll() { result in
            DispatchQueue.main.async {

                switch result {
                case .failure(let error):
                    // TODO: i18n
                    XCTFail("Could not delete documents \(error)")
                case .success:
                    break
                }
            }
        }

        try GRDBDatabase.shared.clear()
        try GRDBDatabase.shared.clearBidirectionalLinks()

        expect(try GRDBDatabase.shared.countBidirectionalLinks()) == 0
        expect(try GRDBDatabase.shared.countIndexedElements()) == 0
    }

    func save(note: BeamNote) {
        let expectation = self.expectation(description: "save note \(note.title)")

        var completion: ((Result<Bool, Error>) -> Void) = { _ in }

        completion = { result in
            switch result {
            case .failure(let error):
                if  note.version != note.savedVersion {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .milliseconds(100))) {
                        note.save(documentManager: self.documentManager, completion: completion)
                    }
                } else {
                    XCTFail(error.localizedDescription)
                }
            case .success:
                expectation.fulfill()
            }
        }
        note.save(documentManager: documentManager, completion: completion)
        wait(for: [expectation], timeout: 0.5)
    }

    func testReferencesAndLinks() {
        let title1 = "test prout"
        let title2 = "Test Bleh"

        let documentManager = DocumentManager()
        let note1 = BeamNote.fetchOrCreate(documentManager, title: title1)
        let note2 = BeamNote.fetchOrCreate(documentManager, title: title2)

        // Now we have two notes that should be ok to tinker with
        expect(try GRDBDatabase.shared.countBidirectionalLinks()) == 0
        // The root element of each note should be there:
        expect(try GRDBDatabase.shared.countIndexedElements()) == 2

        // Now add some contents in the notes
        let element1_1 = BeamElement("this is some text that references a note: \(title2) let's see if we can detect it.")
        note1.addChild(element1_1)
        save(note: note1)

        let element1_2 = BeamElement("this is some text that references a nothing.")
        note2.addChild(element1_2)
        save(note: note2)

        // I expect that no link as been added:
        expect(try GRDBDatabase.shared.countBidirectionalLinks()) == 0
        // However there should be 4 indexed elements now:
        expect(try GRDBDatabase.shared.countIndexedElements()) == 4

        expect(note1.references.count) == 0
        expect(note2.references.count) == 1
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_1.text = BeamText(text: "removing a reference by using another text...")

        expect(note1.references.count) == 0
        expect(note2.references.count) == 0
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_2.text.append(" let's add a reference to '\(title1)' the second note")

        expect(note1.references.count) == 1
        expect(note2.references.count) == 0
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_2.text.append(" What about adding a link to ")
        element1_2.text.append(note1.title, withAttributes: [.internalLink(note1.id)])

        expect(note1.references.count) == 1
        expect(note2.references.count) == 0
        expect(note1.links.count) == 1
        expect(note2.links.count) == 0
        expect(note1.references) == [BeamNoteReference(noteID: note2.id, elementID: element1_2.id)]
        expect(note1.links) == [BeamNoteReference(noteID: note2.id, elementID: element1_2.id)]
    }
}
