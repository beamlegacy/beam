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

    private func searchHistory(_ db: GRDBDatabase,
                               query: String,
                               enabledFrecencyParam: FrecencyParamKey? = nil,
                               successCb: @escaping ([GRDBDatabase.HistorySearchResult]) -> Void,
                               file: StaticString = #file,
                               line: UInt = #line) {
        waitUntil { done in
            db.searchHistory(query: query, enabledFrecencyParam: enabledFrecencyParam) { result in
                switch result {
                case .failure(let error):
                    fail("failed async searchHistory: \(error)", file: file, line: line)
                case .success(let matches):
                    successCb(matches)
                }
                done()
            }
        }
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
        searchHistory(db, query: "Monterey") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match `iPhone` on page content.
        searchHistory(db, query: "iPhone") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Prefix match `iPh` on page content.
        searchHistory(db, query: "iPh") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Prefix match on last token - anyToken match
        searchHistory(db, query: "max pho") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }
        searchHistory(db, query: "max nothing") { matches in
            expect(matches.count) == 0
        }

        // Match with diacritic `écran` on page content.
        searchHistory(db, query: "écran") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match with diacritic `ecran` on page content.
        // Expect the page content to be normalized after tokenization.
        searchHistory(db, query: "ecran") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match token `bar` on page content.
        // Expect the unicode `·` to be treated as a separator during tokenization.
        searchHistory(db, query: "bar") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://unicode-separator.com"
        }

        // Check frecency record is retrieved
        do {
            var frecency = FrecencyUrlRecord(urlId: 0,
                                             lastAccessAt: Date(timeIntervalSince1970: 0),
                                             frecencyScore: 0.42,
                                             frecencySortScore: 0,
                                             frecencyKey: .visit30d0)
            try db.saveFrecencyUrl(&frecency)
            // Match urlId = 0, and check frecency record
            searchHistory(db, query: "Monterey") { matches in
                expect(matches.count) == 1
                guard let f = matches[0].frecency else {
                    fail("expect a frecency record")
                    return
                }
                expect(f.frecencyScore) == 0.42
                expect(f.frecencySortScore) == 0.0
            }
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
        searchHistory(db, query: "foo", enabledFrecencyParam: .visit30d0) { matches in
            expect(matches.count) == 3

            for (expectedUrlId, match) in zip([ 2, 0, 1 ], matches) {
                guard let f = match.frecency else {
                    fail("expect a frecency record")
                    continue
                }
                expect(f.urlId) == UInt64(expectedUrlId)
            }
        }

        // Retrieve search results with frecency sort on .readingTime30d0
        searchHistory(db, query: "foo", enabledFrecencyParam: .readingTime30d0) { matches in
            expect(matches.count) == 1

            for (expectedUrlId, match) in zip([ 2 ], matches) {
                guard let f = match.frecency else {
                    fail("expect a frecency record")
                    continue
                }
                expect(f.urlId) == UInt64(expectedUrlId)
            }
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
        searchHistory(db, query: "Monde") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://www.lemonde.fr/"
        }

        // Match `Mac` in the content. URLs are expected to be different.
        searchHistory(db, query: "Mac") { matches in
            expect(matches.count) == 2
            expect(matches[0].url) == "https://macg.co/article1"
            expect(matches[1].url) == "https://macg.co/article2"
        }
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
        var matches = db.search(matchingAnyTokenIn: "buzz").map { $0.uid }
        expect(matches.count) == 0

        // One match
        matches = db.search(matchingAnyTokenIn: "tata").map { $0.uid }
        expect(matches.count) == 1
        expect(matches) == [note.children[3].id]

        // All tokens matches in multiple records
        matches = db.search(matchingAnyTokenIn: "abcd foo baz").map { $0.uid }
        expect(matches.count) == 3
        expect(matches) == note.children[0...2].map { $0.id }

        // Match on the note title - return all note children
        matches = db.search(matchingAnyTokenIn: "bar note").map { $0.uid }
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
