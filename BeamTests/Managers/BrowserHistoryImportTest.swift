//
//  BrowserHistoryImportTest.swift
//  BeamTests
//
//  Created by Paul Lefkopoulos on 08/12/2021.
//

import XCTest
import Combine
import GRDB
@testable import Beam


class BrowserHistoryTest: XCTestCase {
    var subscriptions: Set<AnyCancellable>!

    func runImporter(importer: BrowserHistoryImporter, dbPath: String, startDate: Date? = nil) throws -> [BrowserHistoryResult] {
        var results = [BrowserHistoryResult]()
        let expectation = XCTestExpectation(description: "Import finished")
        importer.publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished: expectation.fulfill()
                case .failure(let error): XCTFail("Import failed: \(error)")
                }
            },
            receiveValue: { result in
                results.append(result)
            })
        .store(in: &subscriptions)
        try importer.importHistory(from: dbPath, startDate: startDate)
        wait(for: [expectation], timeout: 2.0)
        return results
    }
    override func setUp() {
        subscriptions = Set<AnyCancellable>()
    }
    override func tearDown() {
        subscriptions = Set<AnyCancellable>()
    }
}

//tests that beam can import real history files
class BrowserHistoryImportWithFileTest: BrowserHistoryTest {
    func testChromeImport() throws {
        let bundle = Bundle(for: type(of: self))

        let historyURL = try XCTUnwrap(bundle.url(forResource: "chromeHistory", withExtension: "db"))
        let results = try runImporter(importer: ChromiumHistoryImporter(browser: .chrome), dbPath: historyURL.path)
        XCTAssertEqual(results.count, 3)

        XCTAssertEqual(results[0].item.url?.absoluteString, "https://lemonde.fr/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-08 14:14:35 +0000")
        XCTAssertEqual(results[0].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")

        XCTAssertEqual(results[1].item.url?.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-08 14:14:35 +0000")
        XCTAssertEqual(results[1].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")

        XCTAssertEqual(results[2].item.url?.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[2].item.timestamp.description, "2021-12-08 14:20:36 +0000")
        XCTAssertEqual(results[2].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")
    }
    
    func testSafariImport() throws {
        let bundle = Bundle(for: type(of: self))
        let historyURL = try XCTUnwrap(bundle.url(forResource: "safariHistory", withExtension: "db"))
        let results = try runImporter(importer: SafariImporter(), dbPath: historyURL.path)
        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(results[0].item.url?.absoluteString, "https://twitter.com/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-09 11:08:22 +0000")
        XCTAssertEqual(results[0].item.title, "")

        XCTAssertEqual(results[1].item.url?.absoluteString, "https://twitter.com/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-09 11:08:22 +0000")
        XCTAssertEqual(results[1].item.title, "Twitter. It’s what’s happening / Twitter")
    }

    func testFirefoxImport() throws {
        let bundle = Bundle(for: type(of: self))
        let historyURL = try XCTUnwrap(bundle.url(forResource: "firefoxPlaces", withExtension: "db"))
        let results = try runImporter(importer: FirefoxImporter(), dbPath: historyURL.path)
        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(results[0].item.url?.absoluteString, "http://lemonde.fr/")
        XCTAssertEqual(results[0].item.timestamp.description, "2021-12-09 14:03:29 +0000")
        XCTAssertNil(results[0].item.title)

        XCTAssertEqual(results[1].item.url?.absoluteString, "https://www.lemonde.fr/")
        XCTAssertEqual(results[1].item.timestamp.description, "2021-12-09 14:03:29 +0000")
        XCTAssertEqual(results[1].item.title, "Le Monde.fr - Actualités et Infos en France et dans le monde")
    }
}

//Test importer beahvior in case of faulty history items
class BrowserHistoryImportInMemoryTest: BrowserHistoryTest {
    func testChromeImport() throws {
        let createTablesQuery = """
                CREATE TABLE visits(id INTEGER PRIMARY KEY,url INTEGER NOT NULL,visit_time INTEGER NOT NULL,from_visit INTEGER,transition INTEGER DEFAULT 0 NOT NULL,segment_id INTEGER,visit_duration INTEGER DEFAULT 0 NOT NULL,incremented_omnibox_typed_score BOOLEAN DEFAULT FALSE NOT NULL,publicly_routable BOOLEAN DEFAULT FALSE NOT NULL);
                CREATE TABLE urls(id INTEGER PRIMARY KEY AUTOINCREMENT,url LONGVARCHAR,title LONGVARCHAR,visit_count INTEGER DEFAULT 0 NOT NULL,typed_count INTEGER DEFAULT 0 NOT NULL,last_visit_time INTEGER NOT NULL,hidden INTEGER DEFAULT 0 NOT NULL);
                """
        let visitInsertQuery = "INSERT INTO visits (url, visit_time) VALUES (?, ?)"
        let urlInsertQuery = "INSERT INTO urls (id, url, title, last_visit_time) VALUES (?, ?, ?, ?)"
        let dbPath = "file::memory:?cache=shared"
        let dbQueue = try DatabaseQueue(path: dbPath)
        try dbQueue.write { db in
            try db.execute(sql: createTablesQuery)

            try db.execute(sql: visitInsertQuery, arguments: [0, 0])
            try db.execute(sql: urlInsertQuery, arguments: [0, "http://abc.com", nil, 0])

            try db.execute(sql: visitInsertQuery, arguments: [1, 1 * 1000000])
            try db.execute(sql: urlInsertQuery, arguments: [1, "http://abc.com|", nil, 1])

            try db.execute(sql: visitInsertQuery, arguments: [2, 2 * 1000000])
            try db.execute(sql: urlInsertQuery, arguments: [2, "http://def.com", "alphabet soup", 2])
        }
        var results = try runImporter(importer: ChromiumHistoryImporter(browser: .chrome), dbPath: dbPath)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://abc.com")
        XCTAssertEqual(results[0].item.timestamp.description, "1601-01-01 00:00:00 +0000")
        XCTAssertNil(results[0].item.title)

        XCTAssertEqual(results[1].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[1].item.timestamp.description, "1601-01-01 00:00:02 +0000")
        XCTAssertEqual(results[1].item.title, "alphabet soup")

        //time filtering
        let startDate = ISO8601DateFormatter().date(from: "1601-01-01T00:00:00+0000")
        results = try runImporter(importer: ChromiumHistoryImporter(browser: .chrome), dbPath: dbPath, startDate: startDate)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[0].item.timestamp.description, "1601-01-01 00:00:02 +0000")
        XCTAssertEqual(results[0].item.title, "alphabet soup")
    }

    func testSafariImport() throws {
        let createTablesQuery = """
                CREATE TABLE history_items (id INTEGER PRIMARY KEY AUTOINCREMENT,url TEXT NOT NULL UNIQUE,domain_expansion TEXT NULL,visit_count INTEGER NOT NULL,daily_visit_counts BLOB NOT NULL,weekly_visit_counts BLOB NULL,autocomplete_triggers BLOB NULL,should_recompute_derived_visit_counts INTEGER NOT NULL,visit_count_score INTEGER NOT NULL, status_code INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE history_visits (id INTEGER PRIMARY KEY AUTOINCREMENT,history_item INTEGER NOT NULL REFERENCES history_items(id) ON DELETE CASCADE,visit_time REAL NOT NULL,title TEXT NULL,load_successful BOOLEAN NOT NULL DEFAULT 1,http_non_get BOOLEAN NOT NULL DEFAULT 0,synthesized BOOLEAN NOT NULL DEFAULT 0,redirect_source INTEGER NULL UNIQUE REFERENCES history_visits(id) ON DELETE CASCADE,redirect_destination INTEGER NULL UNIQUE REFERENCES history_visits(id) ON DELETE CASCADE,origin INTEGER NOT NULL DEFAULT 0,generation INTEGER NOT NULL DEFAULT 0,attributes INTEGER NOT NULL DEFAULT 0,score INTEGER NOT NULL DEFAULT 0);
                """
        let visitInsertQuery = "INSERT INTO history_visits (history_item, visit_time, title) VALUES (?, ?, ?)"
        let urlInsertQuery = """
            INSERT INTO history_items (id, url, visit_count, daily_visit_counts, should_recompute_derived_visit_counts, visit_count_score)
            VALUES (?, ?, 0, '', 0, 0)
        """
        let dbPath = "file::memory:?cache=shared"
        let dbQueue = try DatabaseQueue(path: dbPath)
        try dbQueue.write { db in
            try db.execute(sql: createTablesQuery)

            try db.execute(sql: urlInsertQuery, arguments: [0, "http://abc.com"])
            try db.execute(sql: visitInsertQuery, arguments: [0, 0, nil])

            try db.execute(sql: urlInsertQuery, arguments: [1, "http://abc.com|/truc"])
            try db.execute(sql: visitInsertQuery, arguments: [1, 1, nil])

            try db.execute(sql: urlInsertQuery, arguments: [2, "http://def.com"])
            try db.execute(sql: visitInsertQuery, arguments: [2, 2, "alphabet soup"])
        }
        var results = try runImporter(importer: SafariImporter(), dbPath: dbPath)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://abc.com")
        XCTAssertEqual(results[0].item.timestamp.description, "2001-01-01 00:00:00 +0000")
        XCTAssertNil(results[0].item.title)

        XCTAssertEqual(results[1].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[1].item.timestamp.description, "2001-01-01 00:00:02 +0000")
        XCTAssertEqual(results[1].item.title, "alphabet soup")

        //time filtering
        results = try runImporter(importer: SafariImporter(), dbPath: dbPath, startDate: Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[0].item.timestamp.description, "2001-01-01 00:00:02 +0000")
        XCTAssertEqual(results[0].item.title, "alphabet soup")
    }

    func testFirefoxImport() throws {
        let createTablesQuery = """
                CREATE TABLE moz_origins ( id INTEGER PRIMARY KEY, prefix TEXT NOT NULL, host TEXT NOT NULL, frecency INTEGER NOT NULL, UNIQUE (prefix, host) );
                CREATE TABLE moz_places (   id INTEGER PRIMARY KEY, url LONGVARCHAR, title LONGVARCHAR, rev_host LONGVARCHAR, visit_count INTEGER DEFAULT 0, hidden INTEGER DEFAULT 0 NOT NULL, typed INTEGER DEFAULT 0 NOT NULL, frecency INTEGER DEFAULT -1 NOT NULL, last_visit_date INTEGER , guid TEXT, foreign_count INTEGER DEFAULT 0 NOT NULL, url_hash INTEGER DEFAULT 0 NOT NULL , description TEXT, preview_image_url TEXT, origin_id INTEGER REFERENCES moz_origins(id));
                CREATE TABLE moz_historyvisits (  id INTEGER PRIMARY KEY, from_visit INTEGER, place_id INTEGER, visit_date INTEGER, visit_type INTEGER, session INTEGER);
                """
        let visitInsertQuery = "INSERT INTO moz_historyvisits (id, place_id, visit_date) VALUES (?, ?, ?)"
        let urlInsertQuery = "INSERT INTO moz_places (id, url, title) VALUES (?, ?, ?)"
        let dbPath = "file::memory:?cache=shared"
        let dbQueue = try DatabaseQueue(path: dbPath)
        try dbQueue.write { db in
            try db.execute(sql: createTablesQuery)

            try db.execute(sql: visitInsertQuery, arguments: [0, 0, 0])
            try db.execute(sql: urlInsertQuery, arguments: [0, "http://abc.com", nil])

            try db.execute(sql: visitInsertQuery, arguments: [1, 1, 1 * 1_000_000])
            try db.execute(sql: urlInsertQuery, arguments: [1, "http://abc.com|", nil])

            try db.execute(sql: visitInsertQuery, arguments: [2, 2, 2 * 1_000_000])
            try db.execute(sql: urlInsertQuery, arguments: [2, "http://def.com", "alphabet soup"])
        }
        var results = try runImporter(importer: FirefoxImporter(), dbPath: dbPath)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://abc.com")
        XCTAssertEqual(results[0].item.timestamp.description, "1970-01-01 00:00:00 +0000")
        XCTAssertNil(results[0].item.title)

        XCTAssertEqual(results[1].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[1].item.timestamp.description, "1970-01-01 00:00:02 +0000")
        XCTAssertEqual(results[1].item.title, "alphabet soup")

        //time filtering
        results = try runImporter(importer: FirefoxImporter(), dbPath: dbPath, startDate: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].item.url?.absoluteString, "http://def.com")
        XCTAssertEqual(results[0].item.timestamp.description, "1970-01-01 00:00:02 +0000")
        XCTAssertEqual(results[0].item.title, "alphabet soup")
    }
}
