// swiftlint:disable file_length
import BeamCore
import GRDB

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

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = true
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
        guard shouldReindex(note: note) else { return }

        do {
            try dbWriter.write { db in
                try BeamElementRecord.filter(Column("noteId") == note.id.uuidString).deleteAll(db)
                for elem in note.allTexts {
                    var record = BeamElementRecord(title: note.title, text: elem.1.text, uid: elem.0.uuidString, noteId: note.id.uuidString)
                    try record.insert(db)
                }
            }
        } catch {
            Logger.shared.logError("Error while indexing note \(note.title): \(error)", category: .search)
            throw error
        }

        for link in note.internalLinks {
            appendLink(link)
        }

        updateIndexedAt(for: note)
    }

    func append(element: BeamElement) throws {
        guard let note = element.note else { return }
        let noteTitle = note.title
        let noteId = note.id
        do {
            try dbWriter.write { db in
                try BeamElementRecord.filter(Column("noteId") == noteId.uuidString && Column("uid") == element.id.uuidString).deleteAll(db)
                var record = BeamElementRecord(id: nil, title: noteTitle, text: element.text.text, uid: element.id.uuidString, noteId: noteId.uuidString)
                try record.insert(db)
                try BidirectionalLink.filter(Column("sourceElementId") == element.id && Column("sourceNoteId") == noteId).deleteAll(db)
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

    func remove(note: BeamNote) throws {
        let noteId = note.id.uuidString
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(Column("noteId") == noteId).deleteAll(db)
        }
        removeIndexedAt(for: note)
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
        do {
            _ = try dbWriter.write({ db in
                try BeamNoteIndexingRecord
                    .filter(BeamNoteIndexingRecord.Columns.noteId == note.id.uuidString)
                    .deleteAll(db)
            })
        } catch {
            Logger.shared.logError("Error trying to delete note [\(note.id)] indexing date: \(error)", category: .database)

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

    func remove(noteTitled: String) throws {
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(Column("title") == noteTitled).deleteAll(db)
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteId = element.note?.id else { return }
        _ = try dbWriter.write { db in
            try BeamElementRecord.filter(Column("noteId") == noteId.uuidString && Column("uid") == element.id.uuidString).deleteAll(db)
        }
    }

    func clear() throws {
        try dbWriter.write { db in
            try BeamElementRecord.deleteAll(db)
            try HistoryUrlRecord.deleteAll(db)
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
    func insertHistoryUrl(urlId: UInt64, url: String, title: String, content: String?) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO historyUrlRecord (urlId, url, title, content, last_visited_at)
                VALUES (?, ?, ?, ?, datetime('now'))
                """,
                arguments: [urlId, url, title, content ?? ""])
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
                        _ frecencyParam: FrecencyParamKey? = nil,
                        _ completion: @escaping CompletionSearch) {
        dbReader.asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let db = try dbResult.get()
                let results = try search(db, pattern, maxResults, includeText, frecencyParam: frecencyParam)
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
                        frecencyParam: FrecencyParamKey?) throws -> [SearchResult] {
        if let frecencyParam = frecencyParam {
            return try search(db, pattern, maxResults, includeText, frencencyParam: frecencyParam)
        } else {
            return try search(db, pattern, maxResults, includeText)
        }

    }

    /// Search in notes content without frecencies (synchronous).
    private func search(_ db: GRDB.Database,
                        _ pattern: FTS3Pattern?,
                        _ maxResults: Int? = nil,
                        _ includeText: Bool = false) throws -> [SearchResult] {
        var query = pattern != nil ? BeamElementRecord.matching(pattern) : BeamElementRecord.all()
        if let maxResults = maxResults {
            query = query.limit(maxResults)
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
                        frencencyParam: FrecencyParamKey) throws -> [SearchResult] {

        let association = BeamElementRecord.frecency.filter(FrecencyNoteRecord.Columns.frecencyKey == frencencyParam).forKey("frecency")
        var query: QueryInterfaceRequest<BeamElementRecord>
        if let pattern = pattern {
            query = BeamElementRecord.matching(pattern).including(optional: association)
        } else {
            query = BeamElementRecord.all()
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
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, frecencyParam, completion)
    }

    func search(matchingAnyTokenIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, frecencyParam, completion)
    }

    func search(matchingPhrase string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil,
                completion: @escaping CompletionSearch) {
        guard let pattern = FTS3Pattern(matchingPhrase: string) else {
            return completion(.failure(ReadError.invalidFTSPattern))
        }
        search(pattern, maxResults, includeText, frecencyParam, completion)
    }

    func search(matchingAllTokensIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAllTokensIn: string) else {
            return []
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, frecencyParam: frecencyParam)
            }
        } catch {
            return []
        }
    }

    func search(matchingAnyTokenIn string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingAnyTokenIn: string) else {
            return []
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, frecencyParam: frecencyParam)
            }
        } catch {
            return []
        }
    }

    func search(allWithMaxResults maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil) -> [SearchResult] {
        do {
            return try dbReader.read { db in
                try search(db, nil, maxResults, includeText, frecencyParam: frecencyParam)
            }
        } catch {
            return []
        }
    }

    func search(matchingPhrase string: String,
                maxResults: Int? = nil,
                includeText: Bool = false,
                frecencyParam: FrecencyParamKey? = nil) -> [SearchResult] {
        guard let pattern = FTS3Pattern(matchingPhrase: string) else {
            return []
        }
        do {
            return try dbReader.read { db in
                try search(db, pattern, maxResults, includeText, frecencyParam: frecencyParam)
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
        guard var pattern = FTS3Pattern(matchingAnyTokenIn: query) else {
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

    // BidirectionalLinks:
    func appendLink(_ link: BidirectionalLink) {
        appendLink(fromNote: link.sourceNoteId, element: link.sourceElementId, toNote: link.linkedNoteId)
    }

    func appendLink(fromNote: UUID, element: UUID, toNote: UUID) {
        do {
            try dbWriter.write { db in
                var link = BidirectionalLink(sourceNoteId: fromNote, sourceElementId: element, linkedNoteId: toNote)
                try BidirectionalLink
                    .filter(Column("linkedNoteId") == toNote
                        && Column("sourceNoteId") == fromNote
                        && Column("sourceElementId") == element)
                    .deleteAll(db)
                try link.insert(db)
                Logger.shared.logInfo("Append link \(fromNote):\(element) - \(toNote)", category: .search)
            }
        } catch {
            Logger.shared.logError("Error while appending link \(fromNote):\(element) - \(toNote): \(error)", category: .search)
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
//            let all = try BidirectionalLink.fetchAll(db)
            let found = try BidirectionalLink
                .filter(Column("linkedNoteId") == noteId)
                .fetchAll(db)
            return found
        })
    }

    // MARK: - FrecencyUrlRecord

    func saveFrecencyUrl(_ frecencyUrl: inout FrecencyUrlRecord) throws {
        try dbWriter.write { db in
            try frecencyUrl.save(db)
        }
    }

    func fetchOneFrecency(fromUrl: UInt64) throws -> [FrecencyParamKey: FrecencyUrlRecord] {
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

    // MARK: - FrecencyNoteRecord
    func saveFrecencyNote(_ frecencyNote: FrecencyNoteRecord) throws {
        try dbWriter.write { db in
            try frecencyNote.save(db)
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
    func getFrecencyScoreValues(noteIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: Float] {
        var scores = [UUID: Float]()
        let noteIdsStr = noteIds.map { $0.uuidString }
        try? dbReader.read { db in
            return try FrecencyNoteRecord
                .filter(noteIdsStr.contains(FrecencyNoteRecord.Columns.noteId))
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchCursor(db)
                .forEach { scores[$0.noteId] = $0.frecencySortScore }
        }
        return scores
    }

    // MARK: - LongTermUrlScore
    func getLongTermUrlScore(urlId: UInt64) -> LongTermUrlScore? {
        return try? dbReader.read { db in try LongTermUrlScore.fetchOne(db, id: urlId) }
    }

    func updateLongTermUrlScore(urlId: UInt64, changes: (LongTermUrlScore) -> Void ) {
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

    func getManyLongTermUrlScore(urlIds: [UInt64]) -> [LongTermUrlScore] {
        return (try? dbReader.read { db in try LongTermUrlScore.fetchAll(db, ids: urlIds) }) ?? []
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
