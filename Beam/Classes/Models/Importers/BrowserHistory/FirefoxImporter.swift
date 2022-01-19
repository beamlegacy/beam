//
//  FirefoxImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 13/08/2021.
//

import Foundation
import Combine
import GRDB
import INI
import BeamCore

/*
 History database schema:
 CREATE TABLE moz_origins ( id INTEGER PRIMARY KEY, prefix TEXT NOT NULL, host TEXT NOT NULL, frecency INTEGER NOT NULL, UNIQUE (prefix, host) );
 CREATE TABLE moz_places (   id INTEGER PRIMARY KEY, url LONGVARCHAR, title LONGVARCHAR, rev_host LONGVARCHAR, visit_count INTEGER DEFAULT 0, hidden INTEGER DEFAULT 0 NOT NULL, typed INTEGER DEFAULT 0 NOT NULL, frecency INTEGER DEFAULT -1 NOT NULL, last_visit_date INTEGER , guid TEXT, foreign_count INTEGER DEFAULT 0 NOT NULL, url_hash INTEGER DEFAULT 0 NOT NULL , description TEXT, preview_image_url TEXT, origin_id INTEGER REFERENCES moz_origins(id));
 CREATE TABLE moz_historyvisits (  id INTEGER PRIMARY KEY, from_visit INTEGER, place_id INTEGER, visit_date INTEGER, visit_type INTEGER, session INTEGER);
 CREATE TABLE moz_inputhistory (  place_id INTEGER NOT NULL, input LONGVARCHAR NOT NULL, use_count INTEGER, PRIMARY KEY (place_id, input));
 CREATE TABLE moz_bookmarks (  id INTEGER PRIMARY KEY, type INTEGER, fk INTEGER DEFAULT NULL, parent INTEGER, position INTEGER, title LONGVARCHAR, keyword_id INTEGER, folder_type TEXT, dateAdded INTEGER, lastModified INTEGER, guid TEXT, syncStatus INTEGER NOT NULL DEFAULT 0, syncChangeCounter INTEGER NOT NULL DEFAULT 1);
 CREATE TABLE moz_bookmarks_deleted (  guid TEXT PRIMARY KEY, dateRemoved INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE moz_keywords (  id INTEGER PRIMARY KEY AUTOINCREMENT, keyword TEXT UNIQUE, place_id INTEGER, post_data TEXT);
 CREATE TABLE sqlite_sequence(name,seq);
 CREATE TABLE moz_anno_attributes (  id INTEGER PRIMARY KEY, name VARCHAR(32) UNIQUE NOT NULL);
 CREATE TABLE moz_annos (  id INTEGER PRIMARY KEY, place_id INTEGER NOT NULL, anno_attribute_id INTEGER, content LONGVARCHAR, flags INTEGER DEFAULT 0, expiration INTEGER DEFAULT 0, type INTEGER DEFAULT 0, dateAdded INTEGER DEFAULT 0, lastModified INTEGER DEFAULT 0);
 CREATE TABLE moz_items_annos (  id INTEGER PRIMARY KEY, item_id INTEGER NOT NULL, anno_attribute_id INTEGER, content LONGVARCHAR, flags INTEGER DEFAULT 0, expiration INTEGER DEFAULT 0, type INTEGER DEFAULT 0, dateAdded INTEGER DEFAULT 0, lastModified INTEGER DEFAULT 0);
 CREATE TABLE moz_meta (key TEXT PRIMARY KEY, value NOT NULL) WITHOUT ROWID ;
 CREATE TABLE sqlite_stat1(tbl,idx,stat);
 CREATE TABLE moz_places_metadata (id INTEGER PRIMARY KEY, place_id INTEGER NOT NULL, referrer_place_id INTEGER, created_at INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0, total_view_time INTEGER NOT NULL DEFAULT 0, typing_time INTEGER NOT NULL DEFAULT 0, key_presses INTEGER NOT NULL DEFAULT 0, scrolling_time INTEGER NOT NULL DEFAULT 0, scrolling_distance INTEGER NOT NULL DEFAULT 0, document_type INTEGER NOT NULL DEFAULT 0, search_query_id INTEGER, FOREIGN KEY (place_id) REFERENCES moz_places(id) ON DELETE CASCADE, FOREIGN KEY (referrer_place_id) REFERENCES moz_places(id) ON DELETE CASCADE, FOREIGN KEY(search_query_id) REFERENCES moz_places_metadata_search_queries(id) ON DELETE CASCADE CHECK(place_id != referrer_place_id) );
 CREATE TABLE moz_places_metadata_search_queries ( id INTEGER PRIMARY KEY, terms TEXT NOT NULL UNIQUE );
 CREATE INDEX moz_places_url_hashindex ON moz_places (url_hash);
 CREATE INDEX moz_places_hostindex ON moz_places (rev_host);
 CREATE INDEX moz_places_visitcount ON moz_places (visit_count);
 CREATE INDEX moz_places_frecencyindex ON moz_places (frecency);
 CREATE INDEX moz_places_lastvisitdateindex ON moz_places (last_visit_date);
 CREATE UNIQUE INDEX moz_places_guid_uniqueindex ON moz_places (guid);
 CREATE INDEX moz_places_originidindex ON moz_places (origin_id);
 CREATE INDEX moz_historyvisits_placedateindex ON moz_historyvisits (place_id, visit_date);
 CREATE INDEX moz_historyvisits_fromindex ON moz_historyvisits (from_visit);
 CREATE INDEX moz_historyvisits_dateindex ON moz_historyvisits (visit_date);
 CREATE INDEX moz_bookmarks_itemindex ON moz_bookmarks (fk, type);
 CREATE INDEX moz_bookmarks_parentindex ON moz_bookmarks (parent, position);
 CREATE INDEX moz_bookmarks_itemlastmodifiedindex ON moz_bookmarks (fk, lastModified);
 CREATE INDEX moz_bookmarks_dateaddedindex ON moz_bookmarks (dateAdded);
 CREATE UNIQUE INDEX moz_bookmarks_guid_uniqueindex ON moz_bookmarks (guid);
 CREATE UNIQUE INDEX moz_keywords_placepostdata_uniqueindex ON moz_keywords (place_id, post_data);
 CREATE UNIQUE INDEX moz_annos_placeattributeindex ON moz_annos (place_id, anno_attribute_id);
 CREATE UNIQUE INDEX moz_items_annos_itemattributeindex ON moz_items_annos (item_id, anno_attribute_id);
 CREATE UNIQUE INDEX moz_places_metadata_placecreated_uniqueindex ON moz_places_metadata (place_id, created_at);
 */

struct FirefoxHistoryItem: BrowserHistoryItem, Decodable, FetchableRecord {
    var timestamp: Date
    var title: String?
    var url: URL?

    fileprivate enum CodingKeys: String, CodingKey {
        case timestamp = "visit_date"
        case title = "title"
        case url = "url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Double.self, forKey: .timestamp)
        let title = try container.decode(String?.self, forKey: .title)
        let urlStr = try container.decode(String.self, forKey: .url)
        url = URL(string: urlStr)
        // timestamp is number of microseconds since UNIX epoch
        self.timestamp = Date(timeIntervalSince1970: timestamp / 1_000_000)
        self.title = title
    }
}

final class FirefoxImporter: BrowserHistoryImporter {
    let sourceBrowser: BrowserType = .firefox
    enum ImportError: Error {
        case pathNotFoundInDefaultProfile
        case countNotAvailable
    }

    private func defaultDirectoryPath(profilesFile: URL) throws -> String {
        let profiles = try parseINI(filename: profilesFile.path)
        let path = profiles
            .sections
            .filter { $0.name.hasPrefix("Profile") }
            .first { $0.settings["Default"] == "1" }
            .flatMap { $0.settings["Path"] }
        guard let path = path else { throw ImportError.pathNotFoundInDefaultProfile }
        return path
    }

    private func defaultHistoryDatabase(firefoxDirectory: URL) throws -> URL? {
        guard let firefoxProfile = try SandboxEscape.endorsedURL(for: firefoxDirectory.appendingPathComponent("profiles.ini")) else { return nil }
        let directoryPath = try defaultDirectoryPath(profilesFile: firefoxProfile)
        let defaultDirectory = firefoxDirectory.appendingPathComponent(directoryPath, isDirectory: true)
        guard let databaseURL = try SandboxEscape.endorsedURL(for: defaultDirectory.appendingPathComponent("places.sqlite")) else { return nil }
        guard SandboxEscape.endorsedIfExists(url: defaultDirectory.appendingPathComponent("places.sqlite-shm")) else { return nil }
        guard SandboxEscape.endorsedIfExists(url: defaultDirectory.appendingPathComponent("places.sqlite-wal")) else { return nil }
        return databaseURL
    }

    func historyDatabaseURL() throws -> URL? {
        let applicationSupportDirectory = SandboxEscape.actualHomeDirectory().appendingPathComponent("Library").appendingPathComponent("Application Support")
        let firefoxDirectory = applicationSupportDirectory.appendingPathComponent("Firefox")
        return try defaultHistoryDatabase(firefoxDirectory: firefoxDirectory)
    }

    var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>?

    var publisher: AnyPublisher<BrowserHistoryResult, Error> {
        let subject = currentSubject ?? PassthroughSubject<BrowserHistoryResult, Error>()
        currentSubject = subject
        return subject.eraseToAnyPublisher()
    }

    func importHistory(from databaseURL: URL) throws {
        try importHistory(from: databaseURL.path)
    }

    func importHistory(from dbPath: String) throws {
        var configuration = GRDB.Configuration()
        configuration.readonly = true
        let dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
        try dbQueue.read { db in
            do {
                guard let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM moz_historyvisits") else {
                    throw ImportError.countNotAvailable
                }
                let rows = try FirefoxHistoryItem.fetchCursor(db, sql: "SELECT v.visit_date, v.visit_type, v.session, p.url, p.title FROM moz_historyvisits v JOIN moz_places p ON v.place_id = p.id ORDER BY v.visit_date ASC")
                while let row = try rows.next() {
                    if row.url != nil {
                        currentSubject?.send(BrowserHistoryResult(itemCount: itemCount, item: row))
                    }
                }
                currentSubject?.send(completion: .finished)
            } catch {
                currentSubject?.send(completion: .failure(error))
            }
        }
    }
}
