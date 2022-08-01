//
//  BeamNoteLinksAndRefsManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 25/05/2022.
//
// swiftlint:disable file_length

import Foundation
import BeamCore
import GRDB
import UUIDKit

// swiftlint:disable:next type_body_length
class BeamNoteLinksAndRefsManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    public var database: BeamDatabase? {
        holder as? BeamDatabase
    }

    public static var id = UUID()
    public static var name = "BeamNoteLinksAndRefsManager"

    public override var tableNames: [String] { ["BeamElementRecord", "BidirectionalLink", "BeamNoteIndexingRecord", "FrecencyNoteRecord"] }

    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    /// Creates a `GRDBStore`, and make sure the database schema is ready.
    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    // swiftlint:disable:previous type_body_length
    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        // Initialize DB schema
        migrator.registerMigration("createBase") { db in
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

            try db.create(table: "BidirectionalLink", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceNoteId", .blob).indexed()
                t.column("sourceElementId", .blob).indexed()
                t.column("linkedNoteId", .blob).indexed()
            }

            try db.create(table: "BeamNoteIndexingRecord", ifNotExists: true) { t in
                t.column("noteId", .text).primaryKey()
                t.column("indexedAt", .date)
            }

            try db.create(table: "FrecencyNoteRecord", ifNotExists: true) { t in
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
            try db.create(index: "FrecencyNoteIdKeyIndex", on: "FrecencyNoteRecord", columns: ["noteId", "frecencyKey"], unique: true)
            try db.create(index: "FrecencyNoteUpdatedAtIndex", on: "FrecencyNoteRecord", columns: ["updatedAt"], unique: false)

            // There was also this migration but I don't think it's needed anymore now:
//            let threshold = -Float.greatestFiniteMagnitude
//            try db.execute(
//                    sql: """
//                        UPDATE FrecencyNoteRecord
//                        SET
//                            frecencySortScore = :threshold,
//                            updatedAt = :date
//                        WHERE frecencySortScore < :threshold
//                        """,
//                    arguments: ["threshold": threshold, "date": BeamDate.now])
//
//            try db.execute(
//                    sql: """
//                        UPDATE FrecencyUrlRecord
//                        SET
//                            frecencySortScore = :threshold
//                        WHERE frecencySortScore < :threshold
//                        """,
//                    arguments: ["threshold": threshold])

        }
    }

    // MARK: - BeamNote / BeamElement
    func append(note: BeamNote) throws {
        // only reindex note if needed:
        let pivotDate = lastIndexingFor(note: note)
        guard note.updateDate > pivotDate else { return }

        let databaseId = note.databaseId?.uuidString ?? BeamData.shared.currentDatabase?.id.uuidString ?? UUID.null.uuidString
        let noteTitle = note.title
        let noteIdStr = note.id.uuidString
        let records = note.allTextElements.map { BeamElementRecord(title: noteTitle, text: $0.text.text, uid: $0.id.uuidString, noteId: noteIdStr, databaseId: databaseId) }
        let links = note.internalLinks

        BeamNote.indexingQueue.addOperation {
            note.sign.begin(BeamNote.Signs.indexContentsReferences)
            do {
                try self.write { db in
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
            self.appendLinks(links)
            note.sign.end(BeamNote.Signs.indexContentsLinks)

            self.updateIndexedAt(for: note)
        }
    }

    func append(element: BeamElement) throws {
        guard let note = element.note else { return }
        let noteTitle = note.title
        let noteId = note.id
        do {
            try write { db in
                try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
                var record = BeamElementRecord(id: nil, title: noteTitle, text: element.text.text, uid: element.id.uuidString, noteId: noteId.uuidString, databaseId: note.databaseId?.uuidString ?? BeamData.shared.currentDatabase?.id.uuidString ?? UUID.null.uuidString)
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

        DispatchQueue.userInitiated.async {
            do {
                try self.write { db in
                    try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
                    var record = BeamElementRecord(id: nil, title: noteTitle, text: text, uid: elementId.uuidString, noteId: noteId.uuidString, databaseId: note.databaseId?.uuidString ?? BeamData.shared.currentDatabase?.id.uuidString ?? UUID.null.uuidString)
                    try record.insert(db)
                    try BidirectionalLink.filter(BidirectionalLink.Columns.sourceElementId == elementId && BidirectionalLink.Columns.sourceNoteId == noteId).deleteAll(db)
                }

                for link in links {
                    self.appendLink(link)
                }

                _ = try self.write({ db in
                    var noteIndexingRecord = BeamNoteIndexingRecord(id: nil, noteId: noteId.uuidString, indexedAt: BeamDate.now)
                    try BeamNoteIndexingRecord
                        .filter(BeamNoteIndexingRecord.Columns.noteId == noteId.uuidString)
                        .deleteAll(db)
                    try noteIndexingRecord.insert(db)
                })

            } catch {
                Logger.shared.logError("Error while indexing element \(noteTitle) - \(element.id.uuidString): \(error)", category: .search)
            }
            self.updateIndexedAt(for: note)
            completion()
        }
    }

    func remove(note: BeamNote) throws {
        try remove(noteId: note.id)
    }

    func remove(noteId: UUID) throws {
        let noteIdString = noteId.uuidString
        _ = try write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteIdString).deleteAll(db)
            try BidirectionalLink.filter(BidirectionalLink.Columns.sourceNoteId == noteId).deleteAll(db)
        }
        removeIndexedAt(for: noteId)
    }

    func removeNotes(_ noteIds: [UUID]) throws {
        _ = try write { db in
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
            _ = try write({ db in
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
            _ = try write({ db in
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
            result = try self.read({ db in
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
            return try self.read({ db in
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
        _ = try write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.title == noteTitled).deleteAll(db)
        }
    }

    func remove(element: BeamElement) throws {
        guard let noteId = element.note?.id else { return }
        _ = try write { db in
            try BeamElementRecord.filter(BeamElementRecord.Columns.noteId == noteId.uuidString && BeamElementRecord.Columns.uid == element.id.uuidString).deleteAll(db)
        }
    }

    override func clear() throws {
        try clearElements()
        try clearNoteFrecencies()
        try clearBidirectionalLinks()
        try clearNoteIndexingRecord()
    }

    func clearElements() throws {
        _ = try write { db in
            try BeamElementRecord.deleteAll(db)
        }
    }

    func clearBidirectionalLinks() throws {
        _ = try write { db in
            try BidirectionalLink.deleteAll(db)
        }
    }

    func clearNoteIndexingRecord() throws {
        _ = try write { db in
            try BeamNoteIndexingRecord.deleteAll(db)
        }
    }

    func countBidirectionalLinks() throws -> Int {
        return try read { db in
            try BidirectionalLink.fetchCount(db)
        }
    }

    func countIndexedElements() throws -> Int {
        return try read { db in
            try BeamElementRecord.fetchCount(db)
        }
    }

    /// Provides a read-only access to the database.
    enum ReadError: Error {
        case invalidFTSPattern
        case aliasSearchFailed
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
        asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let db = try dbResult.get()
                let results = try self.search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
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
        let databaseId = BeamData.shared.currentDatabase?.id.uuidString ?? UUID.null.uuidString
        var query = self.query(pattern, column: column)
            .filter(BeamElementRecord.Columns.databaseId == databaseId)

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

        let databaseId = BeamData.shared.currentDatabase?.id.uuidString ?? UUID.null.uuidString
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
            return try self.read { db in
                try self.search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
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
            return try self.read { db in
                try self.search(db, pattern, maxResults, includeText, filter: filter, frecencyParam: frecencyParam, column: column)
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
            return try self.read { db in
                try self.search(db, nil, maxResults, includeText, filter: nil, frecencyParam: frecencyParam, column: column)
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
            return try self.read { db in
                try self.search(db, pattern, maxResults, includeText, filter: nil, frecencyParam: frecencyParam, column: column)
            }
        } catch {
            return []
        }
    }

    var linksCount: Int {
        do {
            return try self.read({ db in
                try BidirectionalLink.fetchCount(db)
            })
        } catch {
            Logger.shared.logError("Error while couting links in database: \(error)", category: .database)
            return 0
        }
    }

    var elementsCount: Int {
        do {
            return try self.read({ db in
                try BeamElementRecord.fetchCount(db)
            })
        } catch {
            Logger.shared.logError("Error while couting elements in database: \(error)", category: .database)
            return 0
        }
    }

    // BidirectionalLinks:
    func appendLink(_ link: BidirectionalLink) {
        appendLinks([link])
    }

    func appendLinks(_ links: [BidirectionalLink]) {
        do {
            try write { db in
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
            try write { db in
                let link = BidirectionalLink(sourceNoteId: fromNote, sourceElementId: element, linkedNoteId: toNote)
                try link.delete(db)
            }
        } catch {
            Logger.shared.logError("Error while removing link \(fromNote):\(element) - \(toNote)", category: .search)
        }
    }

    func fetchLinks(toNote noteId: UUID) throws -> [BidirectionalLink] {
        return try self.read({ db in
            let found = try BidirectionalLink
                .filter(BidirectionalLink.Columns.linkedNoteId == noteId)
                .fetchAll(db)
            return found
        })
    }

    // MARK: - FrecencyNoteRecord
    private func save(frecencyNote: FrecencyNoteRecord, db: GRDB.Database) throws {
        guard var existing = try? fetchOneFrecencyNote(noteId: frecencyNote.noteId, paramKey: frecencyNote.frecencyKey, db: db) else {
            try frecencyNote.insert(db)
            return
        }
        if existing.lastAccessAt < frecencyNote.lastAccessAt {
            existing.lastAccessAt = frecencyNote.lastAccessAt
            existing.frecencyScore = frecencyNote.frecencyScore
            existing.frecencySortScore = frecencyNote.frecencySortScore
        }
        existing.updatedAt = BeamDate.now
        existing.deletedAt = frecencyNote.deletedAt
        try existing.update(db)
    }

    func saveFrecencyNote(_ frecencyNote: FrecencyNoteRecord) throws {
        try write { db in try self.save(frecencyNote: frecencyNote, db: db) }
    }
    func save(noteFrecencies: [FrecencyNoteRecord]) throws {
        try write { db in
            for frecency in noteFrecencies {
                try self.save(frecencyNote: frecency, db: db)
            }
        }
    }

    private func fetchOneFrecencyNote(noteId: UUID, paramKey: FrecencyParamKey, db: GRDB.Database) throws -> FrecencyNoteRecord? {
        return try FrecencyNoteRecord
            .filter(FrecencyNoteRecord.Columns.noteId == noteId.uuidString)
            .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
            .fetchOne(db)
    }

    func fetchOneFrecencyNote(noteId: UUID, paramKey: FrecencyParamKey) throws -> FrecencyNoteRecord? {
        return try self.read { db in
            try self.fetchOneFrecencyNote(noteId: noteId, paramKey: paramKey, db: db)
        }
    }
    func fetchNoteFrecencies(noteId: UUID) -> [FrecencyNoteRecord] {
        do {
            return try self.read { db in
                try FrecencyNoteRecord
                    .filter(FrecencyNoteRecord.Columns.noteId == noteId.uuidString)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch frecency for note \(noteId): \(error)", category: .database)
            return []
        }
    }

    func getFrecencyScoreValues(noteIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyNoteRecord] {
        var scores = [UUID: FrecencyNoteRecord]()
        let noteIdsStr = noteIds.map { $0.uuidString }
        try? self.read { db in
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
        try? self.read { db in
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
            return try self.read { db in try FrecencyNoteRecord.fetchAll(db) }
        }
        return try self.read { db in
            try FrecencyNoteRecord.filter(Column("updatedAt") >= updatedSince).fetchAll(db)
        }
    }

    func clearNoteFrecencies() throws {
        _ = try write { db in
            try FrecencyNoteRecord.deleteAll(db)
        }
    }

    func dumpAllLinks() {
        if let links = try? self.read({ db in
            return try BidirectionalLink.fetchAll(db)
        }) {
            //swiftlint:disable:next print
            print("links: \(links)")
        }
    }

}

extension BeamManagerOwner {
    var noteLinksAndRefsManager: BeamNoteLinksAndRefsManager? {
        try? manager(BeamNoteLinksAndRefsManager.self)
    }
}

extension BeamData {
    var noteLinksAndRefsManager: BeamNoteLinksAndRefsManager? {
        currentDatabase?.noteLinksAndRefsManager
    }
}
