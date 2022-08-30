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

class NoteIndexingTests: XCTestCase, BeamDocumentSource {
    static var sourceId: String { "\(Self.self)" }
    override func setUpWithError() throws {
        BeamTestsHelper.logout()
        try AppData.shared.clearAllAccountsAndSetupDefaultAccount()

        expect(try BeamData.shared.noteLinksAndRefsManager?.countBidirectionalLinks()) == 0
        expect(try BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) == 0
    }

    override func tearDownWithError() throws {
        try AppData.shared.clearAllAccountsAndSetupDefaultAccount()
    }

    func testReferencesAndLinks() throws {
        let title1 = "test proud"
        let title2 = "Test Bleh"

        let note1 = try BeamNote.fetchOrCreate(self, title: title1)
        let note2 = try BeamNote.fetchOrCreate(self, title: title2)

        // Now we have two notes that should be ok to tinker with
        expect(try BeamData.shared.noteLinksAndRefsManager?.countBidirectionalLinks()) == 0
        // The root element of each note should be there:
        expect(try BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) == 0

        // Now add some contents in the notes
        let element1_1 = BeamElement("this is some text that references a note: \(title2) let's see if we can detect it.")
        note1.addChild(element1_1)
        XCTAssert(note1.save(self))

        let element1_2 = BeamElement("this is some text that references a nothing.")
        note2.addChild(element1_2)
        XCTAssert(note2.save(self))

        // Explicitely sleep to let the full text search engine index things
        var index = 0
        while note2.references.count != 1,
              (try? BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) != 2,
                index < 5 {
            Thread.sleep(forTimeInterval: 0.5)
          index += 1
        }

        // I expect that no link as been added:
        expect(try BeamData.shared.noteLinksAndRefsManager?.countBidirectionalLinks()) == 0
        // However there should be 4 indexed elements now:
        expect(try BeamData.shared.noteLinksAndRefsManager?.countIndexedElements()) == 2

        expect(note1.references.count) == 0
        expect(note2.references.count) == 1
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_1.text = BeamText(text: "removing a reference by using another text...")

        // Explicitely sleep to let the full text search engine index things
        index = 0
        while note1.references.count != 0 && index < 5 {
            Thread.sleep(forTimeInterval: 0.5)
          index += 1
        }

        expect(note1.references.count) == 0

        expect(note1.references.count) == 0
        expect(note2.references.count) == 0
        expect(note1.links.count) == 0
        expect(note2.links.count) == 0

        element1_2.text.append(" let's add a reference to '\(title1)' the second note")

        _ = note1.save(self)
        _ = note2.save(self)

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

        _ = note1.save(self)
        _ = note2.save(self)

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
