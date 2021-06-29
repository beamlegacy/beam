import GRDB
import Nimble
import XCTest

@testable import Beam
@testable import BeamCore

class GRDBDatabaseHistoryTests: XCTestCase {
    /// Check the GRDBDatabase schema creation can be called twice.
    func testDBReopen() throws {
        let dbQueue = DatabaseQueue()
        _ = try GRDBDatabase(dbQueue)
        _ = try GRDBDatabase(dbQueue)
    }

    func testSearchHistory() throws {
        let db = GRDBDatabase.empty()

        for history in [
            (urlId: 0, url: "https://macg.co", title: "Avec macOS Monterey, le Mac devient un récepteur AirPlay", content: """
La recopie vidéo est également au menu depuis le centre de contrôle de l'appareil iOS. Le Mac prend en charge l'affichage portrait et paysage, et depuis l'app Photos, les clichés peuvent occuper le maximum d'espace possible sur l'écran de l'ordinateur (en zoomant sur l'iPhone, la photo s'agrandira sur le Mac).
""" ),
            (urlId: 1, url: "https://doesnotexists.co", title: "", content: nil),
            (urlId: 2, url: "https://unicode-separator.com", title: "foo·bar", content: nil)
        ] {
            try db.insertHistoryUrl(urlId: UInt64(history.urlId),
                                    url: history.url,
                                    title: history.title,
                                    content: history.content)
        }

        // Match `Monterey` on title.
        var matches = db.searchHistory(query: "Monterey")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match `iPhone` on page content.
        matches = db.searchHistory(query: "iPhone")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Prefix match `iPh` on page content.
        matches = db.searchHistory(query: "iPh")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Prefix match on last token - anyToken match
        matches = db.searchHistory(query: "max pho")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"
        matches = db.searchHistory(query: "max nothing")
        expect(matches.count) == 0

        // Match with diacritic `écran` on page content.
        matches = db.searchHistory(query: "écran")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match with diacritic `ecran` on page content.
        // Expect the page content to be normalized after tokenization.
        matches = db.searchHistory(query: "ecran")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://macg.co"

        // Match token `bar` on page content.
        // Expect the unicode `·` to be treated as a separator during tokenization.
        matches = db.searchHistory(query: "bar")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://unicode-separator.com"

        // Check frecency record is retrieved
        do {
            var frecency = FrecencyUrlRecord(urlId: 0,
                                             lastAccessAt: Date(timeIntervalSince1970: 0),
                                             frecencyScore: 0.42,
                                             frecencySortScore: 0,
                                             frecencyKey: .visit30d0)
            try db.saveFrecencyUrl(&frecency)
            // Match urlId = 0, and check frecency record
            matches = db.searchHistory(query: "Monterey")
            expect(matches.count) == 1
            let f = try XCTUnwrap(matches[0].frecency)
            expect(f.frecencyScore) == 0.42
            expect(f.frecencySortScore) == 0.0
        }
    }

    func testSearchHistoryFrecencySort() throws {
        let db = GRDBDatabase.empty()

        for history in [
            (urlId: 0, url: "https://foobar.co", title: "foo bar", content: ""),
            (urlId: 1, url: "https://foobar1.co", title: "foo baz", content: nil),
            (urlId: 2, url: "https://foobar2.co", title: "foo·bar baz", content: nil)
        ] {
            try db.insertHistoryUrl(urlId: UInt64(history.urlId),
                                    url: history.url,
                                    title: history.title,
                                    content: history.content)
        }

        for f in [
            (urlId: 0, lastAccessAt: Date(), frecencyScore: 0.0, frecencySortScore: 0.42,            frecencyKey: FrecencyParamKey.visit30d0),
            (urlId: 1, lastAccessAt: Date(), frecencyScore: 0.0, frecencySortScore: -0.05,           frecencyKey: FrecencyParamKey.visit30d0),
            (urlId: 2, lastAccessAt: Date(), frecencyScore: 0.0, frecencySortScore: 1.42,            frecencyKey: FrecencyParamKey.visit30d0),
            (urlId: 2, lastAccessAt: Date(), frecencyScore: 0.0, frecencySortScore: -Float.infinity, frecencyKey: FrecencyParamKey.readingTime30d0),
        ] {
            var frecency = FrecencyUrlRecord(urlId: UInt64(f.urlId),
                                             lastAccessAt: f.lastAccessAt,
                                             frecencyScore: Float(f.frecencyScore),
                                             frecencySortScore: Float(f.frecencySortScore),
                                             frecencyKey: f.frecencyKey)
            try db.saveFrecencyUrl(&frecency)
        }

        // Retrieve search results with frecency sort on .visit30d0
        var matches = db.searchHistory(query: "foo", enabledFrecencyParam: .visit30d0)
        expect(matches.count) == 3

        for (expectedUrlId, match) in zip([ 2, 0, 1 ], matches) {
            let frecency = try XCTUnwrap(match.frecency)
            expect(frecency.urlId) == UInt64(expectedUrlId)
        }

        // Retrieve search results with frecency sort on .readingTime30d0
        matches = db.searchHistory(query: "foo", enabledFrecencyParam: .readingTime30d0)
        expect(matches.count) == 1

        for (expectedUrlId, match) in zip([ 2 ], matches) {
            let frecency = try XCTUnwrap(match.frecency)
            expect(frecency.urlId) == UInt64(expectedUrlId)
        }
    }

    /// When a URL is visited multiple times. Searching the DB must the result once.
    func testSearchHistoryIsUnique() throws {
        let db = GRDBDatabase.empty()

        for history in [
            (urlId: 0, url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: ""),
            (urlId: 0, url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: nil),
            (urlId: 1, url: "https://macg.co/article1", title: "", content: "macOS Monterey, le Mac devient un récepteur AirPlay"),
            (urlId: 2, url: "https://macg.co/article2", title: "", content: "Le Mac prend en charge l'affichage portrait et paysage"),
            // TODO: unique with ≠ URL but = urlId
        ] {
            try db.insertHistoryUrl(urlId: UInt64(history.urlId),
                                    url: history.url,
                                    title: history.title,
                                    content: history.content)
        }

        // Match `Monterey` on title.
        var matches = db.searchHistory(query: "Monde")
        expect(matches.count) == 1
        expect(matches[0].url) == "https://www.lemonde.fr/"

        // Match `Mac` in the content. URLs are expected to be different.
        matches = db.searchHistory(query: "Mac")
        expect(matches.count) == 2
        expect(matches[0].url) == "https://macg.co/article1"
        expect(matches[1].url) == "https://macg.co/article2"
    }
}

class GRDBDatabaseBeamElementTests: XCTestCase {
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

    var db : GRDBDatabase! = nil

    override func setUpWithError() throws {
        self.db = GRDBDatabase.empty()
        XCTAssertNoThrow(try db.append(note: note), "note indexing failed")
    }

    func testMatchingAllTokensIn() throws {
        // No match
        var matches = db.search(matchingAllTokensIn: "buzz").map { $0.uid }
        expect(matches.count) == 0

        // One match
        matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[3].id]

        // All tokens matches
        matches = db.search(matchingAllTokensIn: "abcd foo baz").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[2].id]

        // Multiple matches
        matches = db.search(matchingAllTokensIn: "foo abcd").map { $0.uid }
        expect(matches.count) == 2
        expect(matches) == note.children[1...2].map { $0.id }

        // Match on the note title - return all note children
        matches = db.search(matchingAllTokensIn: "bar note").map { $0.uid }
        expect(matches.count) == 5
        expect(matches) == [note.id] + note.children.map { $0.id }
    }

    func testMatchingAnyTokensIn() throws {
        // No match
        var matches = db.search(matchingAnyTokensIn: "buzz").map { $0.uid }
        expect(matches.count) == 0

        // One match
        matches = db.search(matchingAnyTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[3].id]

        // All tokens matches in multiple records
        matches = db.search(matchingAnyTokensIn: "abcd foo baz").map { $0.uid }
        expect(matches.count) == 3
        expect(matches) == note.children[0...2].map { $0.id }

        // Match on the note title - return all note children
        matches = db.search(matchingAnyTokensIn: "bar note").map { $0.uid }
        expect(matches.count) == 5
        expect(matches) == [note.id] + note.children.map { $0.id }
    }

    func testMatchingPhrase() throws {
        let matches = db.search(matchingPhrase: "abcd foo").map { $0.uid }

        expect(matches.count) == 2
        expect(matches) == note.children[1...2].map { $0.id }
    }

    func testSearchMaxResults() throws {
        // Match on the note title - return all note children
        let matches = db.search(matchingAllTokensIn: "bar note", maxResults: 1).map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.id]
    }

    func testClear() throws {
        var matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1

        try db.clear()

        matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 0
    }

    func testRemove() throws {
        var matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 1

        try db.remove(note: note)

        matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 0
    }
}
