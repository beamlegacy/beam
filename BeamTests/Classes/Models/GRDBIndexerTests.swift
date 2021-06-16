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

class GRDBIndexerHistoryTests: XCTestCase {
    var indexer : GRDBIndexer! = nil

    override func setUpWithError() throws {
        let (tmpDir, _) = try FileManager.default.urlForUniqueTemporaryDirectory()
        self.indexer = try GRDBIndexer(dataDir: tmpDir)
    }

    /// Check the indexer can create and reopen the database.
    func testGRDBIndexerDBReopen() throws {
        let (tmpDir, _) = try FileManager.default.urlForUniqueTemporaryDirectory()
        _ = try GRDBIndexer(dataDir: tmpDir)
        _ = try GRDBIndexer(dataDir: tmpDir)
    }

    func testSearchHistory() throws {
        for history in [
            (url: "https://macg.co", title: "Avec macOS Monterey, le Mac devient un récepteur AirPlay", content: """
La recopie vidéo est également au menu depuis le centre de contrôle de l'appareil iOS. Le Mac prend en charge l'affichage portrait et paysage, et depuis l'app Photos, les clichés peuvent occuper le maximum d'espace possible sur l'écran de l'ordinateur (en zoomant sur l'iPhone, la photo s'agrandira sur le Mac).
""" ),
            (url: "https://doesnotexists.co", title: "", content: nil),
            (url: "https://unicode-separator.com", title: "foo·bar", content: nil)
        ] {
            try indexer.insertHistoryUrl(url: history.url, title: history.title, content: history.content)
        }

        // Match `Monterey` on title.
        var matches = indexer.searchHistory(query: "Monterey")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match `iPhone` on page content.
        matches = indexer.searchHistory(query: "iPhone")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Prefix match `iPh` on page content.
        matches = indexer.searchHistory(query: "iPh")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Prefix match on last token - anyToken match
        matches = indexer.searchHistory(query: "max pho")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"
        matches = indexer.searchHistory(query: "max nothing")
        expect(matches.count) == 0

        // Match with diacritic `écran` on page content.
        matches = indexer.searchHistory(query: "écran")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match with diacritic `ecran` on page content.
        // Expect the page content to be normalized after tokenization.
        matches = indexer.searchHistory(query: "ecran")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match token `bar` on page content.
        // Expect the unicode `·` to be treated as a separator during tokenization.
        matches = indexer.searchHistory(query: "bar")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://unicode-separator.com"
    }

    /// When a URL is visited multiple times. Searching the DB must the result once.
    func testSearchHistoryIsUnique() throws {
        for history in [
            (url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: ""),
            (url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: nil),
            (url: "https://macg.co/article1", title: "", content: "macOS Monterey, le Mac devient un récepteur AirPlay"),
            (url: "https://macg.co/article2", title: "", content: "Le Mac prend en charge l'affichage portrait et paysage"),
        ] {
            try indexer.insertHistoryUrl(url: history.url, title: history.title, content: history.content)
        }

        // Match `Monterey` on title.
        var matches = indexer.searchHistory(query: "Monde")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://www.lemonde.fr/"

        // Match `Mac` in the content. URLs are expected to be different.
        matches = indexer.searchHistory(query: "Mac")
        expect(matches.count) == 2
        expect(matches[0].url) == "https://macg.co/article1"
        expect(matches[1].url) == "https://macg.co/article2"
    }
}

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
        let (tmpDir, _) = try FileManager.default.urlForUniqueTemporaryDirectory()
        self.indexer = try GRDBIndexer(dataDir: tmpDir)
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
