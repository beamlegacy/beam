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
    override func setUpWithError() throws {
        BeamTestsHelper.logout()

        DocumentManager().deleteAll() { result in
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

    func testReferencesAndLinks() {
        let title1 = "test prout"
        let title2 = "Test Bleh"

        let note1 = BeamNote.fetchOrCreate(title: title1)
        let note2 = BeamNote.fetchOrCreate(title: title2)

        // Now we have two notes that should be ok to tinker with
        expect(try GRDBDatabase.shared.countBidirectionalLinks()) == 0
        // The root element of each note should be there:
        expect(try GRDBDatabase.shared.countIndexedElements()) == 0

        // Now add some contents in the notes
        let element1_1 = BeamElement("this is some text that references a note: \(title2) let's see if we can detect it.")
        note1.addChild(element1_1)
        XCTAssert(note1.syncedSave())

        let element1_2 = BeamElement("this is some text that references a nothing.")
        note2.addChild(element1_2)
        XCTAssert(note2.syncedSave())


        // Explicitely sleep to let the full text search engine index things
        Thread.sleep(forTimeInterval: 1)

        // I expect that no link as been added:
        expect(try GRDBDatabase.shared.countBidirectionalLinks()) == 0
        // However there should be 4 indexed elements now:
        expect(try GRDBDatabase.shared.countIndexedElements()) == 2

        expect(note1.references.count) == 0
        expect(note2.references.count) == 1
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_1.text = BeamText(text: "removing a reference by using another text...")

        // Explicitely sleep to let the full text search engine index things
        var index = 0
        while note1.references.count != 0 && index < 5 {
          Thread.sleep(forTimeInterval: 1)
          index += 1
        }

        expect(note1.references.count) == 0

        expect(note1.references.count) == 0
        expect(note2.references.count) == 0
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_2.text.append(" let's add a reference to '\(title1)' the second note")

        // Explicitely sleep to let the full text search engine index things
        index = 0
        while note1.references.count != 1 && index < 5 {
          Thread.sleep(forTimeInterval: 1)
          index += 1
        }

        expect(note1.references.count) == 1
        expect(note2.references.count) == 0
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_2.text.append(" What about adding a link to ")
        element1_2.text.append(note1.title, withAttributes: [.internalLink(note1.id)])

        // Explicitely sleep to let the full text search engine index things
        index = 0
        while note1.links.count != 1 && index < 5 {
          Thread.sleep(forTimeInterval: 1)
          index += 1
        }

        expect(note1.references.count) == 1
        expect(note2.references.count) == 0
        expect(note1.links.count) == 1
        expect(note2.links.count) == 0
        expect(note1.references) == [BeamNoteReference(noteID: note2.id, elementID: element1_2.id)]
        expect(note1.links) == [BeamNoteReference(noteID: note2.id, elementID: element1_2.id)]
    }
}
