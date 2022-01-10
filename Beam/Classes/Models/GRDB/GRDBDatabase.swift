// swiftlint:disable file_length
import BeamCore
import GRDB
import Dispatch
import Foundation

/// GRDBDatabase lets the application access the database.
/// It's role is to setup the database schema.
struct GRDBDatabase {
    /// Creates a `GRDBDatabase`, and make sure the database schema is ready.
    //swiftlint:disable:next function_body_length
    public init(_ dbWriter: DatabaseWriter) throws {

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
                t.column("id", .integer).primaryKey()
                t.column("sourceNoteId", .blob).indexed()
                t.column("sourceElementId", .blob).indexed()
                t.column("linkedNoteId", .blob).indexed()
            }
        }

        migrator.registerMigration("createFrecencyUrlRecord") { db in
            // Delete the history
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
            try db.execute(sql: "DROP TABLE HistoryUrlContent")
            try db.execute(sql: "DROP TABLE HistoryUrlRecord")

            try db.create(table: "historyUrlRecord", ifNotExists: true) { t in
                // LinkStore URL id
                t.column("urlId").unique()
                // FIXME: Use only the LinkStore URL id as a primary key
                t.column("url", .text).primaryKey()
                t.column("last_visited_at", .date)
                t.column("title", .text)
                t.column("content", .text)
            }

            // Index title and text in FTS from HistoryUrlRecord.
            try db.create(virtualTable: "historyUrlContent", using: FTS4()) { t in
                t.synchronize(withTable: "historyUrlRecord")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
            }

            try db.create(table: "frecencyUrlRecord", ifNotExists: true) { t in
                t.column("urlId", .integer) // FIXME: with .references("linkStore", column: "urlId")
                t.column("lastAccessAt", .date)
                t.column("frecencyScore", .double)
                t.column("frecencySortScore", .double)
                t.column("frecencyKey")
                t.primaryKey(["urlId", "frecencyKey"])
            }

        }

        migrator.registerMigration("create_index_on_BidirectionalLinks") { db in
            try db.create(table: "NewBidirectionalLink") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceNoteId", .blob).indexed()
                t.column("sourceElementId", .blob).indexed()
                t.column("linkedNoteId", .blob).indexed()
            }

            try db.execute(sql: """
            INSERT INTO NewBidirectionalLink (sourceNoteId, sourceElementId, linkedNoteId)
              SELECT sourceNoteId, sourceElementId, linkedNoteId
              FROM BidirectionalLink;
            """)

            try db.drop(table: "BidirectionalLink")
            try db.rename(table: "NewBidirectionalLink", to: "BidirectionalLink")
            let count = try BidirectionalLink.fetchCount(db)
            Logger.shared.logDebug("Migrated BidirectionalLink table with \(count) records")

        }

        migrator.registerMigration("createLongTermUrlScore") { db in
            try db.create(table: "longTermUrlScore", ifNotExists: true) { t in
                t.column("urlId", .integer).primaryKey()
                t.column("visitCount", .integer)
                t.column("readingTimeToLastEvent", .double)
                t.column("textSelections", .integer)
                t.column("scrollRatioX", .double)
                t.column("scrollRatioY", .double)
                t.column("textAmount", .integer)
                t.column("area", .double)
                t.column("lastCreationDate", .datetime)
            }
        }
        migrator.registerMigration("createFrecencyNoteRecord") { db in
            try db.create(table: "frecencyNoteRecord", ifNotExists: true) { t in
                t.column("noteId", .text)
                t.column("lastAccessAt", .date)
                t.column("frecencyScore", .double)
                t.column("frecencySortScore", .double)
                t.column("frecencyKey")
                t.primaryKey(["noteId", "frecencyKey"])
            }
        }

        migrator.registerMigration("createBeamNoteIndexingRecord") { db in
            try db.create(table: "BeamNoteIndexingRecord", ifNotExists: true) { t in
                t.column("noteId", .text).primaryKey()
                t.column("indexedAt", .date)
            }
        }

        migrator.registerMigration("createBrowsingTreeRecord") { db in
            try db.create(table: "BrowsingTreeRecord", ifNotExists: true) { t in
                t.column("rootId", .text).primaryKey()
                t.column("rootCreatedAt", .date).indexed().notNull()
                t.column("appSessionId", .text)
                t.column("data", .blob).notNull()
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
                t.column("previousChecksum", .text)
            }
        }
        migrator.registerMigration("deleteLegacyUrlIdRelatedRows") { db in
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
            try db.drop(table: "historyUrlRecord")
            try db.drop(table: "historyUrlContent")
            try db.drop(table: "frecencyUrlRecord")
            try db.drop(table: "longTermUrlScore")

            try db.create(table: "historyUrlRecord", ifNotExists: true) { t in
                // LinkStore URL id
                t.column("urlId", .text).primaryKey()
                t.column("url", .text)
                t.column("last_visited_at", .date)
                t.column("title", .text)
                t.column("content", .text)
            }

            // Index title and text in FTS from HistoryUrlRecord.
            try db.create(virtualTable: "historyUrlContent", using: FTS4()) { t in
                t.synchronize(withTable: "historyUrlRecord")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
            }

            try db.create(table: "frecencyUrlRecord", ifNotExists: true) { t in
                t.column("urlId", .text) // FIXME: with .references("linkStore", column: "urlId")
                t.column("lastAccessAt", .date)
                t.column("frecencyScore", .double)
                t.column("frecencySortScore", .double)
                t.column("frecencyKey")
                t.primaryKey(["urlId", "frecencyKey"])
            }

            try db.create(table: "longTermUrlScore", ifNotExists: true) { t in
                t.column("urlId", .text).primaryKey()
                t.column("visitCount", .integer)
                t.column("readingTimeToLastEvent", .double)
                t.column("textSelections", .integer)
                t.column("scrollRatioX", .double)
                t.column("scrollRatioY", .double)
                t.column("textAmount", .integer)
                t.column("area", .double)
                t.column("lastCreationDate", .datetime)
            }
        }

        migrator.registerMigration("addHistoryUrlRecordAliasDomain") { db in
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
            try db.drop(table: "historyUrlRecord")
            try db.drop(table: "historyUrlContent")

            try db.create(table: "historyUrlRecord", ifNotExists: true) { t in
                // LinkStore URL id
                t.column("urlId", .text).primaryKey()
                t.column("url", .text)
                t.column("alias_domain", .text)
                t.column("last_visited_at", .date)
                t.column("title", .text)
                t.column("content", .text)
            }

            // Index title and text in FTS from HistoryUrlRecord.
            try db.create(virtualTable: "historyUrlContent", using: FTS4()) { t in
                t.synchronize(withTable: "historyUrlRecord")
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
            }
        }
        migrator.registerMigration("moveLinkStoreToGRDB") { db in
            try db.create(table: BeamLinkDB.tableName, ifNotExists: true) { table in
                table.column("id", .text).notNull().primaryKey().unique(onConflict: .replace)
                table.column("url", .text).notNull().indexed().unique(onConflict: .replace)
                table.column("title", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }
        }

        migrator.registerMigration("BeamElementRecord_databaseId") { db in
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
                t.column("databaseId")
            }
        }

        migrator.registerMigration("AddIndexToBeamOjectsUpdateAt") { db in
            try db.create(index: "BrowsingTreeRecordUpdatedAt", on: "BrowsingTreeRecord", columns: ["updatedAt"], unique: false)
            try db.create(index: "LinkUpdatedAt", on: "Link", columns: ["updatedAt"], unique: false)
        }

        migrator.registerMigration("AddBeamObjectFieldsToNoteFrecencyRecords") { db in
            try db.create(table: "newFrecencyNoteRecord", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("noteId", .text)
                t.column("lastAccessAt", .date)
                t.column("frecencyScore", .double)
                t.column("frecencySortScore", .double)
                t.column("frecencyKey")
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
            }
            let now = BeamDate.now
            let rows = try Row.fetchCursor(db, sql: """
                SELECT noteId, lastAccessAt, frecencyScore, frecencySortScore, frecencyKey FROM FrecencyNoteRecord
                """
            )
            while let row = try rows.next() {
                try db.execute(
                        sql: """
                            INSERT INTO newFrecencyNoteRecord
                                (id, noteId, lastAccessAt, frecencyScore, frecencySortScore, frecencyKey, createdAt, updatedAt)
                            VALUES
                                (?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [UUID(), row["noteId"], row["lastAccessAt"], row["frecencyScore"], row["frecencySortScore"],
                                   row["frecencyKey"], now, now])
            }

            try db.drop(table: "FrecencyNoteRecord")
            try db.rename(table: "newFrecencyNoteRecord", to: "FrecencyNoteRecord")
            try db.create(index: "FrecencyNoteIdKeyIndex", on: "FrecencyNoteRecord", columns: ["noteId", "frecencyKey"], unique: true)
            try db.create(index: "FrecencyNoteUpdatedAtIndex", on: "FrecencyNoteRecord", columns: ["updatedAt"], unique: false)
        }

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

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
        // only reindex note if needed:
        let pivotDate = lastIndexingFor(note: note)
        guard note.updateDate > pivotDate else { return }

        let databaseId =  note.databaseId?.uuidString ?? Database.defaultDatabase().id.uuidString
        let noteTitle = note.title
        let noteIdStr = note.id.uuidString
        let records = note.allTextElements.map { BeamElementRecord(title: noteTitle, text: $0.text.text, uid: $0.id.uuidString, noteId: noteIdStr, databaseId: databaseId) }
        let links = note.internalLinks

        BeamNote.indexingQueue.async {
            note.sign.begin(BeamNote.Signs.indexContentsReferences)
            do {
                try dbWriter.write { db in
                    try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == note.id.uuidString).deleteAll(db)
                    try BidirectionalLink.filter(BidirectionalLink.Columns.sourceNoteId == note.id).deleteAll(db)
                    for var record in records {
                        try record.save(db)
                    }
                }
            } catch {
                Logger.shared.logError("Error while indexing note \(note.title): \(error)", category: .search)
            }
            note.sign.end(BeamNote.Signs.indexContentsReferences)

            note.sign.begin(BeamNote.Signs.indexContentsLinks)
            appendLinks(links)
            note.sign.end(BeamNote.Signs.indexContentsLinks)

            updateIndexedAt(for: note)
        }
    }

    func append(element: BeamElement) throws {
        guard let note = element.note else { return }
        let noteTitle = note.title
        let noteId = note.id
        do {
            try dbWriter.write { db in
                try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
                var record = BeamElementRecord(id: nil, title: noteTitle, text: element.text.text, uid: element.id.uuidString, noteId: noteId.uuidString, databaseId: note.databaseId?.uuidString ?? Database.defaultDatabase().id.uuidString)
                try record.insert(db)
                try BidirectionalLink.filter(BidirectionalLink.Columns.sourceElementId == element.id && BidirectionalLink.Columns.sourceNoteId == noteId).deleteAll(db)
            }

            for link in element.internalLinksInSelf {
                appendLink(link)
            }
        } catch {
            Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString): \(error)", category: .search)
            throw error
        }
        updateIndexedAt(for: note)
    }

    func appendAsync(element: BeamElement, _ completion: @escaping () -> Void = {}) {
        guard let note = element.note else { return }
        let noteTitle = note.title
        let noteId = note.id
        let elementId = element.id
        let text = element.text.text
        let links = element.internalLinksInSelf

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try dbWriter.write { db in
                    try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
                    var record = BeamElementRecord(id: nil, title: noteTitle, text: text, uid: elementId.uuidString, noteId: noteId.uuidString, databaseId: note.databaseId?.uuidString ?? Database.defaultDatabase().id.uuidString)
                    try record.insert(db)
                    try BidirectionalLink.filter(BidirectionalLink.Columns.sourceElementId == elementId && BidirectionalLink.Columns.sourceNoteId == noteId).deleteAll(db)
                }

                for link in links {
                    appendLink(link)
                }

                _ = try dbWriter.write({ db in
                    var noteIndexingRecord = BeamNoteIndexingRecord(id: nil, noteId: noteId.uuidString, indexedAt: BeamDate.now)
                    try BeamNoteIndexingRecord
                        .filter(BeamNoteIndexingRecord.Columns.noteId == noteId.uuidString)
                        .deleteAll(db)
                    try noteIndexingRecord.insert(db)
                })

            } catch {
                Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString): \(error)", category: .search)
            }
            updateIndexedAt(for: note)
            completion()
        }
    }

    func remove(note: BeamNote) throws {
        try remove(noteId: note.id)
    }

    func remove(noteId: UUID) throws {
        let noteIdString = noteId.uuidString
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteIdString).deleteAll(db)
            try BidirectionalLink.filter(BidirectionalLink.Columns.sourceNoteId == noteId).deleteAll(db)
        }
        removeIndexedAt(for: noteId)
    }

    func removeNotes(_ noteIds: [UUID]) throws {
        _ = try dbWriter.write { db in
            for id in noteIds {
                let idString = id.uuidString
                try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == idString).deleteAll(db)
                try BidirectionalLink.filter(BidirectionalLink.Columns.sourceNoteId == id).deleteAll(db)
                try BidirectionalLink.filter(BidirectionalLink.Columns.linkedNoteId == id).deleteAll(db)
                try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == idString)
                    .deleteAll(db)
            }
        }
    }

    func updateIndexedAt(for note: BeamNote) {
        do {
            _ = try dbWriter.write({ db in
                var noteIndexingRecord = BeamNoteIndexingRecord(id: nil, noteId: note.id.uuidString, indexedAt: BeamDate.now)
                try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == note.id.uuidString)
                    .deleteAll(db)
                try noteIndexingRecord.insert(db)
            })
        } catch {
            Logger.shared.logError("Error trying to add indexing date for note [\(note.id)]: \(error)", category: .database)

        }
    }

    func removeIndexedAt(for note: BeamNote) {
        removeIndexedAt(for: note.id)
    }

    func removeIndexedAt(for noteId: UUID) {
        let noteIdString = noteId.uuidString
        do {
            _ = try dbWriter.write({ db in
                try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == noteIdString)
                    .deleteAll(db)
            })
        } catch {
            Logger.shared.logError("Error trying to delete note [\(noteIdString)] indexing date: \(error)", category: .database)

        }
    }

    func shouldReindex(note: BeamNote) -> Bool {
        var result = true
        do {
            result = try dbReader.read({ db in
                let dates = try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == note.id.uuidString)
                    .fetchAll(db)
                guard dates.count <= 1 else {
                    Logger.shared.logError("There should only be one BeamNoteIndexingRecord instance for note [\(note.id)] but there are \(dates.count)", category: .database)
                    return true
                }

                guard let date = dates.first else {
                    return true
                }

                return note.updateDate >= date.indexedAt
            })
        } catch {
            Logger.shared.logError("Error trying to find if note [\(note.id)] should be reindexed: \(error)", category: .database)
        }
        return result
    }

    func lastIndexingFor(note: BeamNote) -> Date {
        do {
            return try dbReader.read({ db in
                let dates = try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == note.id.uuidString)
                    .fetchAll(db)
                guard dates.count <= 1 else {
                    Logger.shared.logError("There should only be one BeamNoteIndexingRecord instance for note [\(note.id)] but there are \(dates.count)", category: .database)
                    return Date.distantPast
                }

                guard let date = dates.first else {
                    return Date.distantPast
                }

                return date.indexedAt
            })
        } catch {
            Logger.shared.logError("Error trying to find if note [\(note.id)] should be reindexed: \(error)", category: .database)
        }
        return Date.distantPast
    }

    func remove(noteTitled: String) throws {
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.title == noteTitled).deleteAll(db)
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteId = element.note?.id else { return }
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
        }
    }

    func clear() throws {
        try dbWriter.write { db in
            try BeamElementRecord.deleteAll(db)
            try BeamNoteIndexingRecord.deleteAll(db)
            try BidirectionalLink.deleteAll(db)
            try HistoryUrlRecord.deleteAll(db)
            try BrowsingTreeRecord.deleteAll(db)
            try FrecencyUrlRecord.deleteAll(db)
            try FrecencyNoteRecord.deleteAll(db)
            try LongTermUrlScore.deleteAll(db)
            try db.execute(sql: "DELETE FROM HistoryUrlContent")
            try db.dropFTS4SynchronizationTriggers(forTable: "HistoryUrlRecord")
        }
    }

    func clearElements() throws {
        _ = try dbWriter.write { db in
            try BeamElementRecord.deleteAll(db)
        }
    }

    func clearBidirectionalLinks() throws {
        _ = try dbWriter.write { db in
            try BidirectionalLink.deleteAll(db)
        }
    }

    func clearNoteIndexingRecord() throws {
        _ = try dbWriter.write({ db in
            try BeamNoteIndexingRecord.deleteAll(db)
        })
    }

    func countBidirectionalLinks() throws -> Int {
        return try dbWriter.write { db in
            try BidirectionalLink.fetchCount(db)
        }
    }

    func countIndexedElements() throws -> Int {
        return try dbWriter.write { db in
            try BeamElementRecord.fetchCount(db)
        }
    }

    // MARK: - HistoryUrlRecord

    /// Register the URL in the history table associated with a `last_visited_at` timestamp.
    /// - Parameter urlId: URL identifier from the LinkStore
    /// - Parameter url: URL to the page
    /// - Parameter title: Title of the page indexed in FTS
    /// - Parameter text: Content of the page indexed in FTS
    func insertHistoryUrl(urlId: UUID, url: String, aliasDomain: String?, title: String, content: String?) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO historyUrlRecord (urlId, url, alias_domain, title, content, last_visited_at)
                VALUES (?, ?, ?, ?, ?, datetime('now'))
                """,
                arguments: [urlId, url, aliasDomain ?? "", title, content ?? ""])
        }
    }
}

// MARK: - Database Access: Reads

extension GRDBDatabase {
    /// Provides a read-only access to the database.
    var dbReader: DatabaseReader {
        dbWriter
    }

    enum ReadError: Error {
        case invalidFTSPattern
    }

    // MARK: - SearchResult (BeamElement/BeamNote)

    struct SearchResult {
        var title: String
        var noteId: UUID
        var uid: UUID
        var text: String?
        var frecency: FrecencyNoteRecord?
    }

    typealias CompletionSearch = (Result<[SearchResult], Error>) -> Void

    /// Search in notes content (asynchronous).
    private func search(_ pattern: FTS3Pattern,
                        _ maxResults: Int? = nil,
                        _ includeText: Bool = false,
                        _ filter: SQLSpecificExpressible?,
                        _ frecencyParam: FrecencyParamKey? = nil,
                        _ column: BeamElementRecord.Columns? = nil,
                        _ completion: @escaping CompletionSearch) {
        dbReader.asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let db = try dbResult.get()
                let results = try search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }
    /// Search in notes contents (synchronous)
    private func search(_ db: GRDB.Database,
                        _ pattern: FTS3Pattern?,
                        _ maxResults: Int? = nil,
                        _ includeText: Bool = false,
                        filter: SQLSpecificExpressible?,
                        frecencyParam: FrecencyParamKey?,
                        column: BeamElementRecord.Columns? = nil) throws -> [SearchResult] {
        if let frecencyParam = frecencyParam {
            return try search(db, pattern, maxResults, includeText, filter: filter, frencencyParam: frecencyParam)
        } else {
            return try search(db, pattern, maxResults, includeText, filter: filter, column: column)
        }

    }

    private func query(_ pattern: FTS3Pattern?,
                       column: BeamElementRecord.Columns? = nil) -> QueryInterfaceRequest<BeamElementRecord> {
        if let pattern = pattern {
            if let column = column {
                return BeamElementRecord.filter(column.match(pattern))
            } else {
                return BeamElementRecord.matching(pattern)
            }
        }
        return BeamElementRecord.all()
    }

    /// Search in notes content without frecencies (synchronous).
    private func search(_ db: GRDB.Database,
                        _ pattern: FTS3Pattern?,
                        _ maxResults: Int? = nil,
                        _ includeText: Bool = false,
                        filter: SQLSpecificExpressible? = nil,
                        column: BeamElementRecord.Columns? = nil) throws -> [SearchResult] {
        var query = self.query(pattern, column: column)
        if let maxResults = maxResults {
            query = query.limit(maxResults)
        }
        if let filter = filter {
            query = query.filter(filter)
        }
        return try query.fetchAll(db).compactMap { record in
            guard let noteId = record.noteId.uuid,
                  let uid = record.uid.uuid else { return nil }
            return SearchResult(title: record.title, noteId: noteId, uid: uid, text: includeText ? record.text : nil)
        }
    }

    private struct SearchResultWithFrecencies: FetchableRecord {
        var beamElement: BeamElementRecord
        var frecency: FrecencyNoteRecord?

        init(row: Row) {
            beamElement = BeamElementRecord(row: row)
            frecency = row["frecency"]
        }
    }

    /// Search in notes content with frecencies  (synchronous).
    private func search(_ db: GRDB.Database,
                        _ pattern: FTS3Pattern?,
                        _ maxResults: Int? = nil,
                        _ includeText: Bool = false,
                        filter: SQLSpecificExpressible? = nil,
                        frencencyParam: FrecencyParamKey) throws -> [SearchResult] {

        let databaseId = Database.defaultDatabase().id.uuidString
        let association = BeamElementRecord.frecency
            .filter(FrecencyNoteRecord.Columns.frecencyKey == frencencyParam)
            .order(FrecencyNoteRecord.Columns.frecencySortScore.desc)
            .forKey("frecency")
        var query: QueryInterfaceRequest<BeamElementRecord>
        if let pattern = pattern {
            query = BeamElementRecord
                .filter(BeamElementRecord.Columns.databaseId == databaseId)
                .matching(pattern).including(optional: association)
        } else {
            query = BeamElementRecord
                .filter(BeamElementRecord.Columns.databaseId == databaseId)
                .including(optional: association)
        }
        if let filter = filter {
            query = query.filter(filter)
        }
        if let maxResults = maxResults {
            query = query.limit(maxResults)
        }
        return try SearchResultWithFrecencies.fetchAll(db, query).compactMap { record in
            let beamElement = record.beamElement
            guard let noteId = beamElement.noteId.uuid,
                  let uid = beamElement.uid.uuid else { return nil }
            return SearchResult(title: beamElement.title, noteId: noteId, uid: uid, text: includeText ? beamElement.text : nil, frecency: record.frecency)
        }
    }

    func search(matchingAllTokensIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil,
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, nil, frecencyParam, column, completion)
    }

    func search(matchingAnyTokenIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil,
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, nil, frecencyParam, column, completion)
    }

    func search(matchingPhrase string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil,
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingPhrase: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, nil, frecencyParam, column, completion)
    }

    func search(matchingAllTokensIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                excludeElements: [UUID]? = nil,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: string) else {
            return []
        }
        var filter: SQLSpecificExpressible?
        if let excludeElements = excludeElements {
            filter = !excludeElements.map { $0.uuidString }.contains(BeamElementRecord.Columns.uid)
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
            }
        } catch {
            return []
        }
    }

    func search(matchingAnyTokenIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                excludeElements: [UUID]? = nil,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: string) else {
            return []
        }
        var filter: SQLSpecificExpressible?
        if let excludeElements = excludeElements {
            filter = !excludeElements.map { $0.uuidString }.contains(BeamElementRecord.Columns.uid)
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
            }
        } catch {
            return []
        }
    }

    func search(allWithMaxResults maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil) -> [SearchResult] {
        do {
            return try dbReader.read { db in
                try search(db, nil, maxResults, includeText, filter: nil, frecencyParam: frecencyParam, column: column)
            }
        } catch {
            return []
        }
    }

    func search(matchingPhrase string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                column: BeamElementRecord.Columns? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingPhrase: string) else {
            return []
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, filter: nil, frecencyParam: frecencyParam, column: column)
            }
        } catch {
            return []
        }
    }

    var linksCount: Int {
        do {
            return try dbReader.read({ db in
                try BidirectionalLink.fetchCount(db)
            })
        } catch {
            Logger.shared.logError("Error while couting links in database: \(error)", category: .database)
            return 0
        }
    }

    var elementsCount: Int {
        do {
            return try dbReader.read({ db in
                try BeamElementRecord.fetchCount(db)
            })
        } catch {
            Logger.shared.logError("Error while couting elements in database: \(error)", category: .database)
            return 0
        }
    }

    // MARK: - HistorySearchResult

    struct HistorySearchResult {
        let title: String
        let url: String
        let frecency: FrecencyUrlRecord?
    }

    private struct HistoryUrlRecordWithFrecency: FetchableRecord {
        var history: HistoryUrlRecord
        var frecency: FrecencyUrlRecord?

        init(row: Row) {
            history = HistoryUrlRecord(row: row)
            frecency = row[HistoryUrlRecord.frecencyForeign]
        }
    }

    /// Perform a history search query.
    /// - Parameter prefixLast: when enabled the last token is prefix matched.
    /// - Parameter enabledFrecencyParam: select the frecency parameter to use to sort results.
    func searchHistory(query: String,
                       prefixLast: Bool = true,
                       enabledFrecencyParam: FrecencyParamKey? = nil,
                       completion: @escaping (Result<[HistorySearchResult], Error>) -> Void) {
        guard var pattern = FTS3Pattern(matchingAllTokensIn: query) else {
            completion(.failure(ReadError.invalidFTSPattern))
            return
        }
        if prefixLast {
            guard let prefixLastPattern = try? FTS3Pattern(rawPattern: pattern.rawPattern + "*") else {
                completion(.failure(ReadError.invalidFTSPattern))
                return
            }
            pattern = prefixLastPattern
        }

        dbReader.asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let db = try dbResult.get()
                var request = HistoryUrlRecord
                    .joining(required: HistoryUrlRecord.content.matching(pattern))
                    .including(optional: HistoryUrlRecord.frecency)
                if let frecencyParam = enabledFrecencyParam {
                    request = request
                        .filter(literal: "frecencyUrlRecord.frecencyKey = \(frecencyParam)")
                        .order(literal: "frecencyUrlRecord.frecencySortScore DESC")
                }

                let results = try request
                    .asRequest(of: HistoryUrlRecordWithFrecency.self)
                    .fetchAll(db)
                    .map { record -> HistorySearchResult in
                        HistorySearchResult(title: record.history.title,
                                            url: record.history.url,
                                            frecency: record.frecency)
                    }
                completion(.success(results))
            } catch {
                Logger.shared.logError("history search failure: \(error)", category: .search)
                completion(.failure(error))
            }
        }
    }

    func searchAlias(query: String,
                     enabledFrecencyParam: FrecencyParamKey? = nil,
                     completion: @escaping (Result<HistorySearchResult?, Error>) -> Void) {
        dbReader.asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let db = try dbResult.get()
                var request = HistoryUrlRecord
                    .filter(HistoryUrlRecord.Columns.aliasUrl.like("%\(query)%"))
                    .including(optional: HistoryUrlRecord.frecency)
                if let frecencyParam = enabledFrecencyParam {
                    request = request
                        .filter(literal: "frecencyUrlRecord.frecencyKey = \(frecencyParam)")
                        .order(literal: "frecencyUrlRecord.frecencySortScore DESC")
                }
                let result = try request
                    .asRequest(of: HistoryUrlRecordWithFrecency.self)
                    .fetchOne(db)
                    .map { record -> HistorySearchResult in
                        HistorySearchResult(title: record.history.title,
                                            url: record.history.aliasUrl,
                                            frecency: record.frecency)
                    }
                completion(.success(result))
            } catch {
                Logger.shared.logError("history search failure: \(error)", category: .search)
                completion(.failure(error))
            }
        }
    }

    // BidirectionalLinks:
    func appendLink(_ link: BidirectionalLink) {
        appendLinks([link])
    }

    func appendLinks(_ links: [BidirectionalLink]) {
        do {
            try dbWriter.write { db in
                for var link in links {
                    try BidirectionalLink
                        .filter(BidirectionalLink.Columns.sourceNoteId == link.sourceNoteId)
                        .filter(BidirectionalLink.Columns.sourceElementId == link.sourceElementId)
                        .filter(BidirectionalLink.Columns.linkedNoteId == link.linkedNoteId)
                        .deleteAll(db)
                    try link.save(db)
                }
            }
        } catch {
            Logger.shared.logError("Unable to save links in database: \(error)", category: .search)
        }
    }

    func appendLink(fromNote: UUID, element: UUID, toNote: UUID) {
        appendLinks([BidirectionalLink(sourceNoteId: fromNote, sourceElementId: element, linkedNoteId: toNote)])
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
//            let all = try BidirectionalLink.fetchAll(db)
            let found = try BidirectionalLink
                .filter(BidirectionalLink.Columns.linkedNoteId == noteId)
                .fetchAll(db)
            return found
        })
    }

    // MARK: - FrecencyUrlRecord

    func saveFrecencyUrl(_ frecencyUrl: FrecencyUrlRecord) throws {
        try dbWriter.write { db in
            try frecencyUrl.save(db)
        }
    }

    func save(urlFrecencies: [FrecencyUrlRecord]) throws {
        try dbWriter.write { db in
            for frecency in urlFrecencies {
                try frecency.save(db)
            }
        }
    }

    func fetchOneFrecency(fromUrl: UUID) throws -> [FrecencyParamKey: FrecencyUrlRecord] {
        var result = [FrecencyParamKey: FrecencyUrlRecord]()
        for type in FrecencyParamKey.allCases {
            try dbReader.read { db in
                if let record = try FrecencyUrlRecord.fetchOne(db, sql: "SELECT * FROM FrecencyUrlRecord WHERE urlId = ? AND frecencyKey = ?", arguments: [fromUrl, type]) {
                    result[type] = record
                }
            }
        }

        return result
    }
    func getFrecencyScoreValues(urlIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: Float] {
        var scores = [UUID: Float]()
        try? dbReader.read { db in
            return try FrecencyUrlRecord
                .filter(urlIds.contains(FrecencyUrlRecord.Columns.urlId))
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchCursor(db)
                .forEach { scores[$0.urlId] = $0.frecencySortScore }
        }
        return scores
    }

    // MARK: - FrecencyNoteRecord
    func saveFrecencyNote(_ frecencyNote: FrecencyNoteRecord) throws {
        try dbWriter.write { db in
            try frecencyNote.save(db)
        }
    }

    func save(noteFrecencies: [FrecencyNoteRecord]) throws {
        try dbWriter.write { db in
            for frecency in noteFrecencies {
                try frecency.save(db)
            }
        }
    }

    func fetchOneFrecencyNote(noteId: UUID, paramKey: FrecencyParamKey) throws -> FrecencyNoteRecord? {
        try dbReader.read { db in
            return try FrecencyNoteRecord
                .filter(FrecencyNoteRecord.Columns.noteId == noteId.uuidString)
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchOne(db)
        }
    }

    func getFrecencyScoreValues(noteIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyNoteRecord] {
        var scores = [UUID: FrecencyNoteRecord]()
        let noteIdsStr = noteIds.map { $0.uuidString }
        try? dbReader.read { db in
            return try FrecencyNoteRecord
                .filter(noteIdsStr.contains(FrecencyNoteRecord.Columns.noteId))
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchCursor(db)
                .forEach { scores[$0.noteId] = $0 }
        }
        return scores
    }
    func getTopNoteFrecencies(limit: Int = 10, paramKey: FrecencyParamKey) -> [UUID: FrecencyNoteRecord] {
        var scores = [UUID: FrecencyNoteRecord]()
        try? dbReader.read { db in
            return try FrecencyNoteRecord
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .order(FrecencyNoteRecord.Columns.frecencySortScore.desc)
                .limit(limit)
                .fetchCursor(db)
                .forEach { scores[$0.noteId] = $0 }
        }
        return scores
    }
    func allNoteFrecencies(updatedSince: Date?) throws -> [FrecencyNoteRecord] {
        guard let updatedSince = updatedSince else {
            return try dbReader.read { db in try FrecencyNoteRecord.fetchAll(db) }
        }
        return try dbReader.read { db in
            try FrecencyNoteRecord.filter(Column("updatedAt") >= updatedSince).fetchAll(db)
        }
    }

    // MARK: - LongTermUrlScore
    func getLongTermUrlScore(urlId: UUID) -> LongTermUrlScore? {
        return try? dbReader.read { db in try LongTermUrlScore.fetchOne(db, id: urlId) }
    }

    func updateLongTermUrlScore(urlId: UUID, changes: (LongTermUrlScore) -> Void ) {
        do {
            try dbWriter.write {db in
                let score = (try? LongTermUrlScore.fetchOne(db, id: urlId)) ?? LongTermUrlScore(urlId: urlId)
                changes(score)
                try score.save(db)
            }
        } catch {
            Logger.shared.logError("Couldn't update url long term score for \(urlId)", category: .database)
        }
    }

    func getManyLongTermUrlScore(urlIds: [UUID]) -> [LongTermUrlScore] {
        return (try? dbReader.read { db in try LongTermUrlScore.fetchAll(db, ids: urlIds) }) ?? []
    }

    // MARK: - BrowsingTree
    func save(browsingTreeRecord: BrowsingTreeRecord) throws {
        do {
            try dbWriter.write { db in try browsingTreeRecord.save(db) }
        } catch {
            Logger.shared.logError("Couldn't save tree with id \(browsingTreeRecord.rootId)", category: .database)
            throw error
        }
    }
    func save(browsingTreeRecords: [BrowsingTreeRecord]) throws {
        do {
            try dbWriter.write { db in
                try browsingTreeRecords.forEach { (record) in try record.save(db) }
            }
        } catch {
            Logger.shared.logError("Couldn't save trees \(browsingTreeRecords)", category: .database)
            throw error
        }
    }
    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord? {
        try dbReader.read { db in try BrowsingTreeRecord.fetchOne(db, id: rootId) }
    }
    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord] {
        try dbReader.read { db in try BrowsingTreeRecord.fetchAll(db, ids: rootIds) }
    }
    func getAllBrowsingTrees(updatedSince: Date? = nil) throws -> [BrowsingTreeRecord] {
        try dbReader.read { db in
            if let updatedSince = updatedSince {
                return try BrowsingTreeRecord.filter(BrowsingTreeRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try BrowsingTreeRecord.fetchAll(db)
        }
    }
    func exists(browsingTreeRecord: BrowsingTreeRecord) throws -> Bool {
        try dbReader.read { db in
            try browsingTreeRecord.exists(db)
        }
    }
    func browsingTreeExists(rootId: UUID) throws -> Bool {
        try dbReader.read { db in
            try BrowsingTreeRecord.filter(id: rootId).fetchCount(db) > 0
        }
    }
    var countBrowsingTrees: Int? {
        return try? dbReader.read { db in try BrowsingTreeRecord.fetchCount(db) }
    }
    func clearBrowsingTrees() throws {
        _ = try dbWriter.write { db in
            try BrowsingTreeRecord.deleteAll(db)
        }
    }
    func deleteBrowsingTree(id: UUID) throws {
        _ = try dbWriter.write { db in
            try BrowsingTreeRecord.deleteOne(db, id: id)
        }
    }
    func deleteBrowsingTrees(ids: [UUID]) throws {
        _ = try dbWriter.write { db in
            try BrowsingTreeRecord.deleteAll(db, ids: ids)
        }
    }
    // MARK: - LinkStore
    func getLinks(matchingUrl url: String) -> [UUID: Link] {
        var matchingLinks = [UUID: Link]()
        try? dbReader.read { db in
            try Link.filter(Column("url").like("%\(url)%"))
                .fetchAll(db)
                .forEach { matchingLinks[$0.id] = $0 }
        }
        return matchingLinks
    }

    func getTopScoredLinks(matchingUrl url: String, frecencyParam: FrecencyParamKey, limit: Int = 10) -> [LinkWithFrecency] {
        let association = Link.frecencyScores
            .filter(FrecencyUrlRecord.Columns.frecencyKey == frecencyParam)
            .order(FrecencyUrlRecord.Columns.frecencySortScore.desc)
            .forKey("frecency")
        var query: QueryInterfaceRequest<Link>
        query = Link
            .filter(Column("url").like("%.\(url)%") || Column("url").like("%/\(url)%"))
            .including(optional: association)
            .limit(limit)
        return (try? dbReader.read { db in
            try LinkWithFrecency.fetchAll(db, query)
        }) ?? []
    }

    func getOrCreateIdFor(url: String, title: String?) -> UUID {
        (try? dbReader.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)?.id
        }) ?? visit(url: url, title: title).id
    }

    func insert(links: [Link]) throws {
        try dbWriter.write { db in
            for var link in links {
                try link.insert(db)
            }
        }
    }

    func linkFor(id: UUID) -> Link? {
        try? dbReader.read { db in
            try Link.filter(Column("id") == id).fetchOne(db)
        }
    }

    func linkFor(url: String) -> Link? {
        try? dbReader.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)
        }
    }

    func visit(url: String, title: String? = nil) -> Link {
        guard var link = linkFor(url: url) else {
            // The link doesn't exist, create it and return the id
            var link = Link(url: url, title: title)
            _ = try? dbWriter.write { db in
                try link.insert(db)
            }
            return link
        }

        // otherwise let's update the title and the updatedAt
        link.title = title
        link.updatedAt = BeamDate.now
        _ = try? dbWriter.write { db in
            try link.update(db, columns: [Column("updateAt"), Column("title")])
        }
        return link
    }

    func deleteAll() throws {
        _ = try dbWriter.write { db in
            try Link.deleteAll(db)
        }
    }

    func allLinks(updatedSince: Date?) throws -> [Link] {
        guard let updatedSince = updatedSince
        else {
            return try dbReader.read { db in try Link.fetchAll(db) }
        }
        return try dbReader.read { db in
            try Link.filter(Column("updatedAt") >= updatedSince).fetchAll(db)
        }
    }

    func getLinks(ids: [UUID]) throws -> [Link] {
        try dbReader.read { db in
            try Link.filter(keys: ids).fetchAll(db)
        }
    }
}

extension GRDBDatabase {
    func dumpAllLinks() {
        if let links = try? dbWriter.read({ db in
            return try BidirectionalLink.fetchAll(db)
        }) {
            //swiftlint:disable:next print
            print("links: \(links)")
        }
    }
}
