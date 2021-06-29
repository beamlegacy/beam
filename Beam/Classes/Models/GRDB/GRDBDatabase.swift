import BeamCore
import GRDB

/// GRDBDatabase lets the application access the database.
/// It's role is to setup the database schema.
struct GRDBDatabase {
    /// Creates a `GRDBDatabase`, and make sure the database schema is ready.
    init(_ dbWriter: DatabaseWriter) throws {

        self.dbWriter = dbWriter

        // Initialize DB schema
        var needsCardReindexing = false
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createBase") { db in
            if try db.tableExists("BeamElementRecord") {
                try db.execute(sql: "DROP TABLE BeamElementRecord")
                needsCardReindexing = true
            }

            try db.create(virtualTable: "BeamElementRecord", ifNotExists: true, using: FTS4()) { t in // or FTS3(), or FTS5()
                // t.compress = "zip"
                // t.uncompress = "unzip"
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("uid")
                t.column("text")
                t.column("noteId")
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

        migrator.registerMigration("createBidirectionalLinks") { db in
            try db.create(table: "BidirectionalLink", ifNotExists: true) { t in
                t.column("sourceNoteId", .blob)
                t.column("sourceElementId", .blob)
                t.column("linkedNoteId", .blob).primaryKey()
            }
        }

        migrator.registerMigration("addTimestampsToPasswords") { db in
            if try db.tableExists(PasswordsDB.tableName) {
                try db.alter(table: PasswordsDB.tableName) { t in
                    t.add(column: "createdAt", .datetime).notNull()
                    t.add(column: "updatedAt", .datetime).notNull()
                    t.add(column: "deletedAt", .datetime)
                    t.add(column: "previousChecksum", .text)
                }
            }
        }

        try migrator.migrate(dbWriter)

        if needsCardReindexing {
            DispatchQueue.main.async {
                BeamNote.indexAllNotes()
            }
        }
    }

    /// Provides access to the database.
    ///
    /// Application can use a `DatabasePool`.
    /// SwiftUI previews and tests can use a fast in-memory `DatabaseQueue`.
    private let dbWriter: DatabaseWriter
}

// MARK: - Database Access: Writes

extension GRDBDatabase {
    // MARK: - BeamNote / BeamElement
    func append(note: BeamNote) throws {
        do {
            try dbWriter.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
                for elem in note.allTexts {
                    try db.execute(
                        sql: "INSERT INTO BeamElementRecord (title, uid, text, noteId) VALUES (?, ?, ?, ?)",
                        arguments: [note.title, elem.0.uuidString, elem.1.text, note.id.uuidString])
                }
            }
        } catch {
            Logger.shared.logError("Error while indexing note \(note.title)", category: .search)
        }
    }

    func append(element: BeamElement) throws {
        guard let note = element.note else { return }
        let noteTitle = note.title
        let noteId = note.id
        do {
            try dbWriter.write { db in
                try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
                try db.execute(
                    sql: "INSERT INTO BeamElementRecord (title, uid, text, noteId) VALUES (?, ?, ?, ?)",
                    arguments: [noteTitle, element.id.uuidString, element.text.text, noteId])
            }
        } catch {
            Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString)", category: .search)
        }
    }

    func remove(note: BeamNote) throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [note.title])
        }
    }

    func remove(noteTitled: String) throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ?", arguments: [noteTitled])
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteTitle = element.note?.title else { return }
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord WHERE title = ? AND uid = ?", arguments: [noteTitle, element.id.uuidString])
        }
    }

    func clear() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord")
            try db.execute(sql: "DELETE FROM HistoryUrlRecord")
            try db.execute(sql: "DELETE FROM HistoryUrlContent")
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
        }
    }

    func clearElements() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BeamElementRecord")
        }
    }

    func clearBidirectionalLinks() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM BidirectionalLink")
        }
    }

    // MARK: - HistoryUrlRecord

    /// Register the URL in the history table associated with a `last_visited_at` timestamp.
    /// - Parameter url: URL to the page
    /// - Parameter title: Title of the page indexed in FTS
    /// - Parameter text: Content of the page indexed in FTS
    func insertHistoryUrl(url: String, title: String, content: String?) throws {
        try dbWriter.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO HistoryUrlRecord (url, title, content, last_visited_at) VALUES (?, ?, ?, datetime('now'))",
                           arguments: [url, title, content ?? ""])
        }
    }
}

// MARK: - Database Access: Reads

extension GRDBDatabase {
    /// Provides a read-only access to the database.
    var dbReader: DatabaseReader {
        dbWriter
    }

    // MARK: - SearchResult (BeamElement/BeamNote)

    @available(*, deprecated, message: "redundant with BeamElementRecord")
    struct SearchResult {
        var title: String
        var noteId: UUID
        var uid: UUID
        var text: String?
    }

    func search(matchingAllTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: query) else { return [] }
        return search(pattern: pattern, maxResults: maxResults, includeText: includeText)
    }

    func search(matchingAnyTokensIn query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: query) else { return [] }
        return search(pattern: pattern, maxResults: maxResults, includeText: includeText)
    }

    func search(matchingPhrase query: String, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingPhrase: query) else { return [] }
        return search(pattern: pattern, maxResults: maxResults, includeText: includeText)
    }

    func search(pattern: FTS3Pattern, maxResults: Int? = 10, includeText: Bool = false) -> [SearchResult] {
        do {
            let results = try dbReader.read { db -> [SearchResult] in
                var query = BeamElementRecord.matching(pattern)
                if let maxResults = maxResults {
                    query = query.limit(maxResults)
                }
                return try query.fetchAll(db).compactMap { record -> SearchResult? in
                    guard let noteId = record.noteId.uuid,
                          let uid = record.uid.uuid else { return nil }
                    return SearchResult(title: record.title, noteId: noteId, uid: uid, text: includeText ? record.text : nil)
                }
            }
            return results
        } catch {
            Logger.shared.logError("Search Error \(error)", category: .search)
            return []
        }
    }

    // MARK: - HistorySearchResult

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
            let results = try dbReader.read { db -> [HistorySearchResult] in
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

    // BidirectionalLinks:
    func appendLink(_ link: BidirectionalLink) {
        appendLink(fromNote: link.sourceNoteId, element: link.sourceElementId, toNote: link.linkedNoteId)
    }

    func appendLink(fromNote: UUID, element: UUID, toNote: UUID) {
        do {
            try dbWriter.write { db in
                var link = BidirectionalLink(sourceNoteId: fromNote, sourceElementId: element, linkedNoteId: toNote)
                try link.insert(db)
                Logger.shared.logInfo("Append link \(fromNote):\(element) - \(toNote)", category: .search)
            }
        } catch {
            Logger.shared.logError("Error while appending link \(fromNote):\(element) - \(toNote)", category: .search)
        }
    }

    func removeLink(fromNote: UUID, element: UUID, toNote: UUID) {
        do {
            try dbWriter.write { db in
                let link = BidirectionalLink(sourceNoteId: fromNote, sourceElementId: element, linkedNoteId: toNote)
                try link.delete(db)
            }
        } catch {
            Logger.shared.logError("Error while removing link \(fromNote):\(element) - \(toNote)", category: .search)
        }
    }

    func fetchLinks(toNote noteId: UUID) throws -> [BidirectionalLink] {
        Logger.shared.logInfo("Fetch links for note \(noteId)", category: .search)
        return try dbWriter.read({ db in
            return try BidirectionalLink.fetchAll(db, keys: [noteId])
        })
    }
}
