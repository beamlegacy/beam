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

    private func searchLink(_ db: GRDBDatabase,
                            query: String,
                            prefixLast: Bool = true,
                            enabledFrecencyParam: FrecencyParamKey? = nil,
                            successCb: @escaping ([GRDBDatabase.LinkSearchResult]) -> Void,
                            file: StaticString = #file,
                            line: UInt = #line) {
        waitUntil { done in
            db.searchLink(query: query, prefixLast: prefixLast, enabledFrecencyParam: enabledFrecencyParam) { result in
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
            (url: "https://macg.co", title: "Avec macOS Monterey, le Mac devient un récepteur AirPlay", content: """
La recopie vidéo est également au menu depuis le centre de contrôle de l'appareil iOS. Le Mac prend en charge l'affichage portrait et paysage, et depuis l'app Photos, les clichés peuvent occuper le maximum d'espace possible sur l'écran de l'ordinateur (en zoomant sur l'iPhone, la photo s'agrandira sur le Mac).
""" ),
            (url: "https://doesnotexists.co", title: "", content: nil),
            (url: "https://unicode-separator.com", title: "foo·bar", content: nil)
        ] {
            db.visit(url: history.url, title: history.title, content: history.content, destination: nil)
        }

        // Match `Monterey` on title.
        searchLink(db, query: "Monterey") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match `iPhone` on page content.
        searchLink(db, query: "iPhone") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Prefix match `iPh` on page content.
        searchLink(db, query: "iPh") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Prefix match on last token - allTokens match
        searchLink(db, query: "maximum pho") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }
        searchLink(db, query: "max pho") { matches in
            expect(matches.count) == 0
        }

        // Match with diacritic `écran` on page content.
        searchLink(db, query: "écran") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match with diacritic `ecran` on page content.
        // Expect the page content to be normalized after tokenization.
        searchLink(db, query: "ecran") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://macg.co"
        }

        // Match token `bar` on page content.
        // Expect the unicode `·` to be treated as a separator during tokenization.
        searchLink(db, query: "bar") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://unicode-separator.com"
        }

        // Check frecency record is retrieved
        do {
            let frecency = FrecencyUrlRecord(urlId: LinkStore.getOrCreateIdFor("https://macg.co"),
                                             lastAccessAt: Date(timeIntervalSince1970: 0),
                                             frecencyScore: 0.42,
                                             frecencySortScore: 0,
                                             frecencyKey: .webVisit30d0)
            try db.saveFrecencyUrl(frecency)
            // Match urlId = 0, and check frecency record
            searchLink(db, query: "Monterey", prefixLast: false) { matches in
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
        let urlIds = [
            LinkStore.getOrCreateIdFor("https://foobar.co"),
            LinkStore.getOrCreateIdFor("https://foobar1.co"),
            LinkStore.getOrCreateIdFor("https://foobar2.co"),
        ]

        for history in [
            (urlId: urlIds[0], url: "https://foobar.co", title: "foo bar", content: ""),
            (urlId: urlIds[1], url: "https://foobar1.co", title: "foo baz", content: nil),
            (urlId: urlIds[2], url: "https://foobar2.co", title: "foo·bar baz", content: nil)
        ] {
            db.visit(url: history.url, title: history.title, content: history.content, destination: nil)
        }

        for f in [
            (urlId: urlIds[0], lastAccessAt: BeamDate.now, frecencyScore: 0.0, frecencySortScore: 0.42,            frecencyKey: FrecencyParamKey.webVisit30d0),
            (urlId: urlIds[1], lastAccessAt: BeamDate.now, frecencyScore: 0.0, frecencySortScore: -0.05,           frecencyKey: FrecencyParamKey.webVisit30d0),
            (urlId: urlIds[2], lastAccessAt: BeamDate.now, frecencyScore: 0.0, frecencySortScore: 1.42,            frecencyKey: FrecencyParamKey.webVisit30d0),
            (urlId: urlIds[2], lastAccessAt: BeamDate.now, frecencyScore: 0.0, frecencySortScore: -Float.infinity, frecencyKey: FrecencyParamKey.webReadingTime30d0),
        ] {
            let frecency = FrecencyUrlRecord(urlId: f.urlId,
                                             lastAccessAt: f.lastAccessAt,
                                             frecencyScore: Float(f.frecencyScore),
                                             frecencySortScore: Float(f.frecencySortScore),
                                             frecencyKey: f.frecencyKey)
            try db.saveFrecencyUrl(frecency)
        }

        // Retrieve search results with frecency sort on .visit30d0
        searchLink(db, query: "foo", enabledFrecencyParam: .webVisit30d0) { matches in
            expect(matches.count) == 3

            for (expectedUrlId, match) in zip([urlIds[2], urlIds[0], urlIds[1]], matches) {
                guard let f = match.frecency else {
                    fail("expect a frecency record")
                    continue
                }
                expect(f.urlId) == expectedUrlId
            }
        }

        // Retrieve search results with frecency sort on .readingTime30d0
        searchLink(db, query: "foo", enabledFrecencyParam: .webReadingTime30d0) { matches in
            expect(matches.count) == 1

            for (expectedUrlId, match) in zip([ urlIds[2] ], matches) {
                guard let f = match.frecency else {
                    fail("expect a frecency record")
                    continue
                }
                expect(f.urlId) == expectedUrlId
            }
        }
    }

    /// When a URL is visited multiple times. Searching the DB must the result once.
    func testSearchHistoryIsUnique() throws {
        let db = GRDBDatabase.empty()
        let urldIds = (0...2).map  { _ in UUID() }
        for history in [
            (urlId: urldIds[0], url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: ""),
            (urlId: urldIds[0], url: "https://www.lemonde.fr/", title: "Le Monde.fr", content: nil),
            (urlId: urldIds[1], url: "https://macg.co/article1", title: "", content: "macOS Monterey, le Mac devient un récepteur AirPlay"),
            (urlId: urldIds[2], url: "https://macg.co/article2", title: "", content: "Le Mac prend en charge l'affichage portrait et paysage"),
            // TODO: unique with ≠ URL but = urlId
        ] {
            db.visit(url: history.url, title: history.title, content: history.content, destination: nil)
        }

        // Match `Monterey` on title.
        searchLink(db, query: "Monde") { matches in
            expect(matches.count) == 1
            expect(matches[0].url) == "https://www.lemonde.fr/"
        }

        // Match `Mac` in the content. URLs are expected to be different.
        searchLink(db, query: "Mac") { matches in
            expect(matches.count) == 2
            expect(matches[0].url) == "https://macg.co/article1"
            expect(matches[1].url) == "https://macg.co/article2"
        }
    }
}

class GRDBDatabaseBeamElementTests: XCTestCase {
    /// Basic note content to check FTS behaviour.
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
        expect(matches.count) == 4
        expect(matches) == note.children.map { $0.id }
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
        expect(matches.count) == 4
        expect(matches) == note.children.map { $0.id }
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
        expect(matches) == [note.children.first?.id]
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
        expect(self.db.elementsCount) == 4

        try db.remove(note: note)
        expect(self.db.elementsCount) == 0

        matches = db.search(matchingAllTokensIn: "tata").map { $0.uid }
        expect(matches.count) == 0
    }

    func testMatchingNotesWithMatchingFrecency() throws {
        let noteId = note.id
        let frecencies = [
            FrecencyNoteRecord(noteId: noteId, lastAccessAt: Date(), frecencyScore: 1, frecencySortScore: 2, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: noteId, lastAccessAt: Date(), frecencyScore: 3, frecencySortScore: 4, frecencyKey: .note30d1)
        ]
        for frecency in frecencies {
            try db.saveFrecencyNote(frecency)
        }
        let scores = db.search(matchingAnyTokenIn: "tata", frecencyParam: .note30d0).map { $0.frecency?.frecencyScore }
        expect(scores.count) == 1
        expect(scores) == [1.0]
    }

    func testMatchingNotesWithoutMatchingFrecency() throws {
        let scores = db.search(matchingAnyTokenIn: "tata", frecencyParam: .note30d0).map { $0.frecency?.frecencyScore }
        expect(scores.count) == 1
        expect(scores) == [nil]
    }
}

class GRDBDatabaseBeamElementWithFrecencyTests: XCTestCase {
        lazy var notes: [BeamNote] = {
            var notes = [BeamNote]()
            let titleAndContents = [
                ["note 1", "la mer"],
                ["note 2", "la mer"],
                ["note 3", "la mer"],
                ["note 4", "le sable"],
            ]
            for noteData in titleAndContents {
                let note = BeamNote(title: noteData[0])
                note.addChild(BeamElement(noteData[1]))
                notes.append(note)
            }
            return notes
        }()

        var db : GRDBDatabase! = nil

        override func setUpWithError() throws {
            self.db = GRDBDatabase.empty()
            do {
                for note in notes { try db.append(note: note) }
            } catch {
                XCTFail("note indexing failed")
            }
        }

    func testSearchRanked() throws {
        let frecencies = [
            FrecencyNoteRecord(noteId: notes[0].id, lastAccessAt: Date(), frecencyScore: 5, frecencySortScore: 10, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: notes[0].id, lastAccessAt: Date(), frecencyScore: 4, frecencySortScore: 8, frecencyKey: .note30d1),
            FrecencyNoteRecord(noteId: notes[1].id, lastAccessAt: Date(), frecencyScore: 3, frecencySortScore: 7, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: notes[2].id, lastAccessAt: Date(), frecencyScore: 1, frecencySortScore: 2, frecencyKey: .note30d0),
            FrecencyNoteRecord(noteId: notes[3].id, lastAccessAt: Date(), frecencyScore: 4.5, frecencySortScore: 9, frecencyKey: .note30d1),

        ]
        for frecency in frecencies {
            try db.saveFrecencyNote(frecency)
        }
        let scores = db.search(matchingAllTokensIn:"la mer", maxResults: 2, frecencyParam: .note30d0).map { $0.frecency?.frecencySortScore }
        expect(scores.count) == 2
        expect(scores) == [10.0, 7.0]
    }
}
