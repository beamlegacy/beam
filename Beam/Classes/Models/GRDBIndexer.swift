//
//  GRDBIndexer.swift
//  Beam
//
//  Created by Sebastien Metrot on 13/04/2021.
//

import Foundation
import BeamCore
import GRDB
import NaturalLanguage

struct IndexDocument: Codable {
    var id: UInt64
    var title: String = ""
    var language: NLLanguage = .undetermined
    var length: Int = 0
    var contentsWords = [String]()
    var titleWords = [String]()
    var tagsWords = [String]()
    var outboundLinks = [UInt64]()

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case title = "t"
    }
}

extension IndexDocument {
    init(source: String, title: String, language: NLLanguage? = nil, contents: String, outboundLinks: [String] = []) {
        self.id = LinkStore.createIdFor(source, title: title)
        self.title = title
        self.language = language ?? (NLLanguageRecognizer.dominantLanguage(for: contents) ?? .undetermined)
        self.outboundLinks = outboundLinks.compactMap({ link -> UInt64? in
            // Only register links that points to cards or to pages we have really visited:
            guard let id = LinkStore.getIdFor(link) else { return nil }
//            guard LinkStore.isInternalLink(id: id) else { return nil }
            return id
        })
        length = contents.count
    }

    var leanCopy: IndexDocument {
        return IndexDocument(id: id, title: title, language: language, length: length, contentsWords: [], titleWords: [], tagsWords: [])
    }
}

struct BeamElementRecord {
    var id: Int64?
    var title: String
    var uid: String
    var text: String
}

// SQL generation
extension BeamElementRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, title, uid, text
    }
}

// Fetching methods
extension BeamElementRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        title = row[Columns.title]
        uid = row[Columns.uid]
        text = row[Columns.text]
    }
}

// Persistence methods
extension BeamElementRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.title] = title
        container[Columns.uid] = uid
        container[Columns.text] = text
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class GRDBIndexer {
    var dbQueue: DatabasePool

    /// Compute the DB filename based on the CI JobID.
    /// - Parameter dataDir: URL of the directory storing the database.
    static func storeURLFromEnv(dataDir: URL) -> URL {
        var suffix = "-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for GRDB sqlite file: \(jobId)", category: .search)

            suffix = "\(Configuration.env)-\(jobId)"
        }

        return dataDir.appendingPathComponent("GRDB\(suffix).sqlite")
    }

    init(dataDir: URL) throws {
        let path = Self.storeURLFromEnv(dataDir: dataDir).string
        let configuration = GRDB.Configuration()

        dbQueue = try DatabasePool(path: path, configuration: configuration)
        try createDatabases(db: dbQueue)
    }

    func createDatabases(db: DatabasePool) throws {
        try dbQueue.write { db in
            try db.create(virtualTable: "BeamElementRecord", ifNotExists: true, using: FTS4()) { t in // or FTS3(), or FTS5()
//                t.compress = "zip"
//                t.uncompress = "unzip"
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("uid")
                t.column("text")
            }

            try db.create(table: "HistoryUrlRecord", ifNotExists: true) { t in
                t.column("url", .text).primaryKey()
                t.column("last_visited_at", .date)
                t.column("title", .text)
                t.column("content", .text)
            }

            // Index title and text in FTS from HistoryUrlRecord.
            if try !db.tableExists("HistoryUrlContent") {
                try db.create(virtualTable: "HistoryUrlContent", using: FTS4()) { t in
                    t.synchronize(withTable: "HistoryUrlRecord")
                    t.tokenizer = .unicode61()
                    t.column("title")
                    t.column("content")
                }
            }
        }
    }

    struct SearchResult {
        var title: String
        var uid: String
        var text: String?
    }

    func search(matchingAllTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(matchingAnyTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(matchingPhrase query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingPhrase: query) else { return [] }
        return search(pattern: pattern, includeText: includeText)
    }

    func search(pattern: FTS3Pattern, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        do {
            let results = try dbQueue.read({ db -> [SearchResult] in
                try BeamElementRecord.matching(pattern).fetchAll(db).map({ record -> SearchResult in
                    return SearchResult(title: record.title, uid: record.uid, text: includeText ? record.text : nil)
                })
            })
            return results
        } catch {
            Logger.shared.logError("Search Error \(error)", category: .search)
            return []
        }
    }

    func append(note: BeamNote) throws {
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
                for elem in note.allTexts {
                    try db.execute(
                        sql: "INSERT INTO BeamElementRecord (title, uid, text) VALUES (?, ?, ?)",
                        arguments: [note.title, elem.0.uuidString, elem.1.text])
                }
            }
        } catch {
            Logger.shared.logError("Error while indexing note \(note.title)", category: .search)
        }
    }

    func append(element: BeamElement) throws {
        guard let noteTitle = element.note?.title else { return }
        do {
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
                try db.execute(
                    sql: "INSERT INTO BeamElementRecord (title, uid, text) VALUES (?, ?, ?)",
                    arguments: [noteTitle, element.id.uuidString, element.text.text])
            }
        } catch {
            Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString)", category: .search)
        }
    }

    func remove(note: BeamNote) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
        }
    }

    func remove(noteTitled: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [noteTitled])
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteTitle = element.note?.title else { return }
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
        }
    }

    func clear() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord")
            try db.execute(sql: "DELETE FROM HistoryUrlRecord")
            try db.execute(sql: "DELETE FROM HistoryUrlContent")
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
        }
    }

    // MARK: - History

    /// Register the URL in the history table associated with a `last_visited_at` timestamp.
    /// - Parameter url: URL to the page
    /// - Parameter title: Title of the page indexed in FTS
    /// - Parameter text: Content of the page indexed in FTS
    func insertHistoryUrl(url: String, title: String, content: String?) throws {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO HistoryUrlRecord (url, title, content, last_visited_at) VALUES (?, ?, ?, datetime('now'))",
                           arguments: [url, title, content ?? ""])
        }
    }

    struct HistorySearchResult {
        var title: String
        var url: String
    }

    func searchHistory(query: String, prefixLast: Bool = true) -> [HistorySearchResult] {
        guard var pattern = FTS3Pattern(matchingAnyTokenIn: query) else { return [] }
        if prefixLast {
            guard let prefixLastPattern = try? FTS3Pattern(rawPattern: pattern.rawPattern + "*") else { return [] }
            pattern = prefixLastPattern
        }

        do {
            let results = try dbQueue.read { db -> [HistorySearchResult] in
                let request = HistoryUrlRecord.joining(required: HistoryUrlRecord.content.matching(pattern))
                return try request.fetchAll(db).map { record -> HistorySearchResult in
                    HistorySearchResult(title: record.title, url: record.url)
                }
            }
            return results
        } catch {
            Logger.shared.logError("history search failure: \(error)", category: .search)
            return []
        }
    }
}

struct HistoryUrlRecord {
    var id: Int64?
    var title: String
    var url: String
    var content: String
}

// SQL generation
extension HistoryUrlRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, url, title, content
    }
}

// Fetching methods
extension HistoryUrlRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        url = row[Columns.url]
        title = row[Columns.title]
        content = row[Columns.content] ?? ""
    }
}

// FTS search
extension HistoryUrlRecord {
    struct FTS: TableRecord {
        static let databaseTableName = "HistoryUrlContent"
    }

    // Association to perform a key join on both `rowid` columns.
    static let content = hasOne(FTS.self, using: ForeignKey(["rowid"], to: ["rowid"]))
}

extension HistoryUrlRecord: MutablePersistableRecord {
    /// The values persisted in the database
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.url] = url
        container[Columns.title] = title
        container[Columns.content] = content
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
