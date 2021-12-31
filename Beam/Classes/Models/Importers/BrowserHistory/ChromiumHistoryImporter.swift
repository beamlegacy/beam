//
//  ChromiumHistoryImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 13/08/2021.
//

import Foundation
import Combine
import GRDB

/*
 History database schema:
 CREATE TABLE meta(key LONGVARCHAR NOT NULL UNIQUE PRIMARY KEY, value LONGVARCHAR);
 CREATE TABLE urls(id INTEGER PRIMARY KEY AUTOINCREMENT,url LONGVARCHAR,title LONGVARCHAR,visit_count INTEGER DEFAULT 0 NOT NULL,typed_count INTEGER DEFAULT 0 NOT NULL,last_visit_time INTEGER NOT NULL,hidden INTEGER DEFAULT 0 NOT NULL);
 CREATE TABLE sqlite_sequence(name,seq);
 CREATE TABLE visits(id INTEGER PRIMARY KEY,url INTEGER NOT NULL,visit_time INTEGER NOT NULL,from_visit INTEGER,transition INTEGER DEFAULT 0 NOT NULL,segment_id INTEGER,visit_duration INTEGER DEFAULT 0 NOT NULL,incremented_omnibox_typed_score BOOLEAN DEFAULT FALSE NOT NULL,publicly_routable BOOLEAN DEFAULT FALSE NOT NULL);
 CREATE TABLE visit_source(id INTEGER PRIMARY KEY,source INTEGER NOT NULL);
 CREATE INDEX visits_url_index ON visits (url);
 CREATE INDEX visits_from_index ON visits (from_visit);
 CREATE INDEX visits_time_index ON visits (visit_time);
 CREATE TABLE keyword_search_terms (keyword_id INTEGER NOT NULL,url_id INTEGER NOT NULL,term LONGVARCHAR NOT NULL,normalized_term LONGVARCHAR NOT NULL);
 CREATE INDEX keyword_search_terms_index1 ON keyword_search_terms (keyword_id, normalized_term);
 CREATE INDEX keyword_search_terms_index2 ON keyword_search_terms (url_id);
 CREATE INDEX keyword_search_terms_index3 ON keyword_search_terms (term);
 CREATE TABLE downloads (id INTEGER PRIMARY KEY,guid VARCHAR NOT NULL,current_path LONGVARCHAR NOT NULL,target_path LONGVARCHAR NOT NULL,start_time INTEGER NOT NULL,received_bytes INTEGER NOT NULL,total_bytes INTEGER NOT NULL,state INTEGER NOT NULL,danger_type INTEGER NOT NULL,interrupt_reason INTEGER NOT NULL,hash BLOB NOT NULL,end_time INTEGER NOT NULL,opened INTEGER NOT NULL,last_access_time INTEGER NOT NULL,transient INTEGER NOT NULL,referrer VARCHAR NOT NULL,site_url VARCHAR NOT NULL,tab_url VARCHAR NOT NULL,tab_referrer_url VARCHAR NOT NULL,http_method VARCHAR NOT NULL,by_ext_id VARCHAR NOT NULL,by_ext_name VARCHAR NOT NULL,etag VARCHAR NOT NULL,last_modified VARCHAR NOT NULL,mime_type VARCHAR(255) NOT NULL,original_mime_type VARCHAR(255) NOT NULL);
 CREATE TABLE downloads_url_chains (id INTEGER NOT NULL,chain_index INTEGER NOT NULL,url LONGVARCHAR NOT NULL, PRIMARY KEY (id, chain_index) );
 CREATE TABLE downloads_slices (download_id INTEGER NOT NULL,offset INTEGER NOT NULL,received_bytes INTEGER NOT NULL,finished INTEGER NOT NULL DEFAULT 0,PRIMARY KEY (download_id, offset) );
 CREATE TABLE segments (id INTEGER PRIMARY KEY,name VARCHAR,url_id INTEGER NON NULL);
 CREATE INDEX segments_name ON segments(name);
 CREATE INDEX segments_url_id ON segments(url_id);
 CREATE TABLE segment_usage (id INTEGER PRIMARY KEY,segment_id INTEGER NOT NULL,time_slot INTEGER NOT NULL,visit_count INTEGER DEFAULT 0 NOT NULL);
 CREATE INDEX segment_usage_time_slot_segment_id ON segment_usage(time_slot, segment_id);
 CREATE INDEX segments_usage_seg_id ON segment_usage(segment_id);
 CREATE TABLE typed_url_sync_metadata (storage_key INTEGER PRIMARY KEY NOT NULL,value BLOB);
 CREATE INDEX urls_url_index ON urls (url);
 CREATE TABLE content_annotations (visit_id INTEGER PRIMARY KEY,floc_protected_score DECIMAL(3, 2),categories VARCHAR,page_topics_model_version INTEGER,annotation_flags INTEGER DEFAULT 0 NOT NULL);
 */

struct ChromiumHistoryItem: BrowserHistoryItem, Decodable, FetchableRecord {
    var timestamp: Date
    var title: String?
    var url: URL?

    fileprivate enum CodingKeys: String, CodingKey {
        case timestamp = "visit_time"
        case title = "title"
        case url = "url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Double.self, forKey: .timestamp)
        let title = try container.decode(String?.self, forKey: .title)
        let urlStr = try container.decode(String.self, forKey: .url)
        url = URL(string: urlStr)
        self.timestamp = Date(timeIntervalSince1970: timestamp)
        self.title = title
    }
}

final class ChromiumHistoryImporter: BrowserHistoryImporter {
    enum ImportError: Error {
        case countNotAvailable
    }

    var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>?

    var publisher: AnyPublisher<BrowserHistoryResult, Error> {
        let subject = currentSubject ?? PassthroughSubject<BrowserHistoryResult, Error>()
        currentSubject = subject
        return subject.eraseToAnyPublisher()
    }

    private var browser: ChromiumBrowserInfo

    init(browser: ChromiumBrowserInfo) {
        self.browser = browser
    }

    func historyDatabaseURL() throws -> URL? {
        let applicationSupportDirectory = SandboxEscape.actualHomeDirectory().appendingPathComponent("Library").appendingPathComponent("Application Support")
        let chromiumDirectory = applicationSupportDirectory.appendingPathComponent(browser.databaseDirectory).appendingPathComponent("Default")
        return try SandboxEscape.endorsedURL(for: chromiumDirectory.appendingPathComponent("History"))
    }

    func importHistory(from databaseURL: URL) throws {
        try importHistory(from: databaseURL.path)
    }

    func importHistory(from dbPath: String) throws {
        let dbQueue = try DatabaseQueue(path: dbPath)
        try dbQueue.read { db in
            do {
                guard let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM visits") else {
                    throw ImportError.countNotAvailable
                }
                // visit_time is number of microseconds since 1601-01-01
                let rows = try ChromiumHistoryItem.fetchCursor(db, sql: "SELECT v.visit_time / 1000000 + strftime('%s', '1601-01-01 00:00:00') AS visit_time, v.visit_duration, u.url, u.title FROM visits v JOIN urls u ON v.url = u.id ORDER BY v.visit_time ASC")
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
