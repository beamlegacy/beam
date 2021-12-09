//
//  SafariImporter.swift
//  Beam
//
//  Created by Frank Lefebvre on 22/07/2021.
//

import Foundation
import Combine
import GRDB

/*
 History database schema:
 CREATE TABLE history_items (id INTEGER PRIMARY KEY AUTOINCREMENT,url TEXT NOT NULL UNIQUE,domain_expansion TEXT NULL,visit_count INTEGER NOT NULL,daily_visit_counts BLOB NOT NULL,weekly_visit_counts BLOB NULL,autocomplete_triggers BLOB NULL,should_recompute_derived_visit_counts INTEGER NOT NULL,visit_count_score INTEGER NOT NULL, status_code INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE sqlite_sequence(name,seq);
 CREATE TABLE history_visits (id INTEGER PRIMARY KEY AUTOINCREMENT,history_item INTEGER NOT NULL REFERENCES history_items(id) ON DELETE CASCADE,visit_time REAL NOT NULL,title TEXT NULL,load_successful BOOLEAN NOT NULL DEFAULT 1,http_non_get BOOLEAN NOT NULL DEFAULT 0,synthesized BOOLEAN NOT NULL DEFAULT 0,redirect_source INTEGER NULL UNIQUE REFERENCES history_visits(id) ON DELETE CASCADE,redirect_destination INTEGER NULL UNIQUE REFERENCES history_visits(id) ON DELETE CASCADE,origin INTEGER NOT NULL DEFAULT 0,generation INTEGER NOT NULL DEFAULT 0,attributes INTEGER NOT NULL DEFAULT 0,score INTEGER NOT NULL DEFAULT 0);
 */

struct SafariHistoryItem: BrowserHistoryItem, Decodable, FetchableRecord {
    var timestamp: Date
    var title: String?
    var url: URL

    fileprivate enum CodingKeys: String, CodingKey {
        case timestamp = "visit_time"
        case title = "title"
        case url = "url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestampStr = try container.decode(String.self, forKey: .timestamp)
        let title = try container.decode(String?.self, forKey: .title)
        let urlStr = try container.decode(String.self, forKey: .url)
        guard let timestampValue = Double(timestampStr) else { throw DecodingError.dataCorruptedError(forKey: .timestamp, in: container, debugDescription: "Expected numeric timestamp") }
        guard let url = URL(string: urlStr) ?? URL(string: String(urlStr.prefix(while: { $0 != "?" }))) else { throw DecodingError.dataCorruptedError(forKey: .url, in: container, debugDescription: "Invalid URL") }
        self.timestamp = Date(timeIntervalSinceReferenceDate: timestampValue)
        self.title = title
        self.url = url
    }
}

final class SafariImporter: BrowserHistoryImporter {
    enum ImportError: Error {
        case countNotAvailable
    }

    private var currentSubject: PassthroughSubject<BrowserHistoryResult, Error>?

    var publisher: AnyPublisher<BrowserHistoryResult, Error> {
        let subject = currentSubject ?? PassthroughSubject<BrowserHistoryResult, Error>()
        currentSubject = subject
        return subject.eraseToAnyPublisher()
    }

    func historyDatabaseURL() throws -> URL? {
        let safariDirectory = SandboxEscape.actualHomeDirectory().appendingPathComponent("Library").appendingPathComponent("Safari")
        let historyDatabase = safariDirectory.appendingPathComponent("History.db")
        let databaseURL = try SandboxEscape.endorsedURL(for: historyDatabase)
        guard try SandboxEscape.endorsedURL(for: safariDirectory.appendingPathComponent("History.db-shm")) != nil else { return nil }
        guard try SandboxEscape.endorsedURL(for: safariDirectory.appendingPathComponent("History.db-wal")) != nil else { return nil }
        return databaseURL
    }

    func importHistory(from databaseURL: URL) throws {
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        try? dbQueue.read { db in
            do {
                guard let itemCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM history_visits") else {
                    throw ImportError.countNotAvailable
                }
                let rows = try SafariHistoryItem.fetchCursor(db, sql: "SELECT v.visit_time, v.title, v.load_successful, i.url, i.domain_expansion, i.status_code, v.origin, v.generation, v.attributes FROM history_visits v JOIN history_items i ON v.history_item = i.id ORDER BY v.visit_time ASC")
                while let row = try rows.next() {
                    currentSubject?.send(BrowserHistoryResult(itemCount: itemCount, item: row))
                }
                currentSubject?.send(completion: .finished)
            } catch {
                currentSubject?.send(completion: .failure(error))
            }
        }
    }
}
