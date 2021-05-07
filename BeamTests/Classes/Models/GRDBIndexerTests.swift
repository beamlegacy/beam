//
//  GRDBIndexer.swift
//  BeamTests
//
//  Created by Pierre Pagnoux on 05/05/2021.
//

import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class GRDBIndexerTests: XCTestCase {
    ///< Basic note content to check FTS behaviour.
    lazy var note: BeamNote = {
        let note = BeamNote(title: "My bar note")

        for c in [
            "foo bar baz",
            "abcd foo",
            "abcd foo baz",
            "titi toto tata",
        ] {
            note.addChild(BeamElement(c))
        }

        return note
    }()

    var indexer : GRDBIndexer! = nil

    override func setUpWithError() throws {
        self.indexer = try GRDBIndexer(path: TemporaryFile(creatingTempDirectoryForFilename: "testDB").fileURL.path)
        XCTAssertNoThrow(try indexer.append(note: note), "note indexing failed")
    }

    func testMatchingAllTokensIn() throws {
        // No match
        var matches = indexer.search(matchingAllTokensIn: "buzz").map { $0.uid }
        expect(matches.count) == 0

        // One match
        matches = indexer.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[3].id.uuidString]

        // All tokens matches
        matches = indexer.search(matchingAllTokensIn: "abcd foo baz").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[2].id.uuidString]

        // Multiple matches
        matches = indexer.search(matchingAllTokensIn: "foo abcd").map { $0.uid }
        expect(matches.count) == 2
        expect(matches) == note.children[1...2].map { $0.id.uuidString }

        // Match on the note title - return all note children
        matches = indexer.search(matchingAllTokensIn: "bar note").map { $0.uid }
        expect(matches.count) == 5
        expect(matches) == [note.id.uuidString] + note.children.map { $0.id.uuidString }
    }

    func testMatchingAnyTokensIn() throws {
        // No match
        var matches = indexer.search(matchingAnyTokensIn: "buzz").map { $0.uid }
        expect(matches.count) == 0

        // One match
        matches = indexer.search(matchingAnyTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[3].id.uuidString]

        // All tokens matches in multiple records
        matches = indexer.search(matchingAnyTokensIn: "abcd foo baz").map { $0.uid }
        expect(matches.count) == 3
        expect(matches) == note.children[0...2].map { $0.id.uuidString }

        // Match on the note title - return all note children
        matches = indexer.search(matchingAnyTokensIn: "bar note").map { $0.uid }
        expect(matches.count) == 5
        expect(matches) == [note.id.uuidString] + note.children.map { $0.id.uuidString }
    }

    func testMatchingPhrase() throws {
        let matches = indexer.search(matchingPhrase: "abcd foo").map { $0.uid }

        expect(matches.count) == 2
        expect(matches) == note.children[1...2].map { $0.id.uuidString }
    }

    func testClear() throws {
        var matches = indexer.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1

        try indexer.clear()

        matches = indexer.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 0
    }

    func testRemove() throws {
        var matches = indexer.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1

        try indexer.remove(note: note)

        matches = indexer.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 0
    }
}
