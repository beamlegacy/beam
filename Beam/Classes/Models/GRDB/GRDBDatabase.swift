// swiftlint:disable file_length
import BeamCore
import GRDB
import Dispatch
import Foundation

/// GRDBDatabase lets the application access the database.
/// It's role is to setup the database schema.
///
/// this file needs clean up https://linear.app/beamapp/issue/BE-3317/clean-up-grdbdatabaseswift
struct GRDBDatabase {
    // swiftlint:disable:previous type_body_length

    /// Creates a `GRDBDatabase`, and make sure the database schema is ready.
    public init(_ dbWriter: DatabaseWriter, migrate: Bool = true) throws {
        // swiftlint:disable:previous function_body_length cyclomatic_complexity
        self.dbWriter = dbWriter

        // Initialize DB schema
        var needsCardReindexing = false
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

        migrator.registerMigration("RemoveInfinityFromFrecencies") { db in
            let threshold = -Float.greatestFiniteMagnitude
            try db.execute(
                    sql: """
                        UPDATE FrecencyNoteRecord
                        SET
                            frecencySortScore = :threshold,
                            updatedAt = :date
                        WHERE frecencySortScore < :threshold
                        """,
                    arguments: ["threshold": threshold, "date": BeamDate.now])

            try db.execute(
                    sql: """
                        UPDATE FrecencyUrlRecord
                        SET
                            frecencySortScore = :threshold
                        WHERE frecencySortScore < :threshold
                        """,
                    arguments: ["threshold": threshold])
        }

        migrator.registerMigration("create_MnemonicRecord") { db in
            try db.create(table: "MnemonicRecord", ifNotExists: true) { t in
                t.column("text", .text).unique(onConflict: .replace).primaryKey()
                t.column("url", .text)
                t.column("last_visited_at", .date)
            }
        }

        migrator.registerMigration("addContentToLinkDB") { db in
            try db.alter(table: BeamLinkDB.tableName, body: { tableAlteration in
                tableAlteration.add(column: "content", .text).defaults(to: "")
            })

            // Index title and text in FTS from Link.
            try db.create(virtualTable: Link.FTS.databaseTableName, using: FTS4()) { t in
                t.tokenizer = .unicode61()
                t.column("title")
                t.column("content")
                t.synchronize(withTable: BeamLinkDB.tableName)
            }

            do {
                for history in try HistoryUrlRecord.fetchAll(db) {
                    guard var link = try Link.filter(Column("url") == history.url).fetchOne(db) else {
                        var link = Link(url: history.url, title: history.title, content: history.content, destination: nil)
                        try link.insert(db)
                        continue
                    }

                    // otherwise let's update the title and the updatedAt
                    link.title = history.title
                    link.content = history.content
                    link.setDestination(nil)
                    link.updatedAt = BeamDate.now

                    try link.update(db, columns: [Column("updateAt"), Column("title"), Column("content"), Column("destination")])
                }
            } catch {
                Logger.shared.logError("Unable to fetch all history urls: \(error)", category: .search)
            }

            //try HistoryUrlRecord.deleteAll(db)
        }

        migrator.registerMigration("addDestinationToLinkDB") { db in
            try db.alter(table: BeamLinkDB.tableName, body: { tableAlteration in
                tableAlteration.add(column: "destination", .blob).indexed()
            })
        }

        migrator.registerMigration("addTreeProcessingStatus") { db in
            try db.alter(table: "BrowsingTreeRecord") { table in
                table.add(column: "processingStatus", .integer).notNull().indexed().defaults(to: 2)
            }
        }

        migrator.registerMigration("flattenBrowsingTrees") { db in
            let rows = try Row.fetchAll(db, sql: "SELECT rootId, data from BrowsingTreeRecord")
            let decoder = BeamJSONDecoder()
            let encoder = JSONEncoder()
            let now = BeamDate.now
            for row in rows {
                let rootId = row["rootId"] as UUID
                let data = row["data"] as Data
                let tree = try decoder.decode(BrowsingTree.self, from: data)
                let flattened = tree.flattened
                let flattenedData = try encoder.encode(flattened)
                try db.execute(sql: """
                    UPDATE BrowsingTreeRecord
                    SET data = :data, updatedAt = :updatedAt
                    WHERE rootId = :rootId
                """, arguments: ["data": flattenedData, "rootId": rootId, "updatedAt": now])
            }
            try db.alter(table: "BrowsingTreeRecord") { t in
                t.rename(column: "data", to: "flattenedData")
            }
        }

        migrator.registerMigration("moveUrlVisitFrecenciesToLinkDB") { db in
            try db.alter(table: "Link") { table in
                table.add(column: "frecencyVisitLastAccessAt", .date)
                table.add(column: "frecencyVisitScore", .double)
                table.add(column: "frecencyVisitSortScore", .double)
            }
            //update values with existing frecencies
            let rows = try Row.fetchCursor(db, sql: """
                                SELECT urlId, lastAccessAt, frecencyScore, frecencySortScore
                                FROM FrecencyUrlRecord
                                WHERE frecencyKey = 0 -- FrecencyParamKey.webVisit30d0
                """)
            let now = BeamDate.now
            while let row = try rows.next() {
                let arguments: StatementArguments = [
                    "urlId": row["urlId"] as UUID,
                    "lastAccessAt": row["lastAccessAt"] as Date,
                    "frecencyScore": row["frecencyScore"] as Float,
                    "frecencySortScore": row["frecencySortScore"] as Float,
                    "updatedAt": now
                ]
                try db.execute(sql: """
                    UPDATE Link
                    SET
                        frecencyVisitLastAccessAt = :lastAccessAt,
                        frecencyVisitScore = :frecencyScore,
                        frecencyVisitSortScore = :frecencySortScore,
                        updatedAt = :updatedAt
                    WHERE id = :urlId
                """, arguments: arguments)
            }
        }

        migrator.registerMigration("createPinTabSuggestiongTables") { db in
            try db.create(table: "BrowsingTreeStats", ifNotExists: true) { t in
                t.column("treeId", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("readingTime", .double)
                t.column("lifeTime", .double)
            }

            try db.create(table: "DomainPath0TreeStats", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("domainPath0", .text).notNull()
                t.column("treeId", .text).notNull()
                t.column("readingTime", .double)
            }
            try db.create(index: "DomainPath0TreeStatsIndex", on: "domainPath0TreeStats", columns: ["treeId", "domainPath0"], unique: true)

            try db.create(table: "DomainPath0ReadingDay", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("domainPath0", .text).indexed()
                t.column("readingDay", .date).indexed()
                t.uniqueKey(["domainPath0", "readingDay"], onConflict: .ignore)
            }
        }
        migrator.registerMigration("trackPinTabSuggestions") { db in
            try db.create(table: "TabPinSuggestion", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("domainPath0", .text).indexed()
                t.uniqueKey(["domainPath0"], onConflict: .ignore)
            }
        }
        migrator.registerMigration("dropBrowsingTreeRecordNonNullContraint") { db in
            try db.create(table: "newBrowsingTreeRecord", ifNotExists: true) { t in
                t.column("rootId", .text).primaryKey()
                t.column("rootCreatedAt", .date).indexed().notNull()
                t.column("appSessionId", .text)
                t.column("flattenedData", .blob) //not null constraint dropped
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
                t.column("previousChecksum", .text)
                t.column("processingStatus", .integer).notNull().indexed().defaults(to: 2)
            }
            try db.execute(sql: """
                INSERT INTO newBrowsingTreeRecord
                SELECT * FROM BrowsingTreeRecord
                """)
            try db.drop(table: "BrowsingTreeRecord")
            try db.rename(table: "newBrowsingTreeRecord", to: "BrowsingTreeRecord")
        }
        migrator.registerMigration("createDailyUrlScoreTable") { db in
            try db.create(table: "DailyUrlScore", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("urlId", .blob).indexed().notNull()
                t.column("localDay", .text).indexed().notNull()
                t.column("visitCount", .integer).notNull()
                t.column("readingTimeToLastEvent", .double).notNull()
                t.column("textSelections", .integer).notNull()
                t.column("scrollRatioX", .double).notNull()
                t.column("scrollRatioY", .double).notNull()
                t.column("textAmount", .integer).notNull()
                t.column("area", .double).notNull()
                t.uniqueKey(["urlId", "localDay"])
            }
        }

        migrator.registerMigration("addNonNullConstraintsToLongTermUrlScores") { db in
            try db.create(table: "newLongTermUrlScore", ifNotExists: true) { t in
                t.column("urlId", .text).primaryKey()
                t.column("visitCount", .integer).notNull()
                t.column("readingTimeToLastEvent", .double).notNull()
                t.column("textSelections", .integer).notNull()
                t.column("scrollRatioX", .double).notNull()
                t.column("scrollRatioY", .double).notNull()
                t.column("textAmount", .integer).notNull()
                t.column("area", .double).notNull()
                t.column("lastCreationDate", .datetime)
            }
            try db.execute(sql: """
                INSERT INTO newLongTermUrlScore
                SELECT * FROM LongTermUrlScore
                WHERE
                    visitCount IS NOT NULL
                    AND readingTimeToLastEvent IS NOT NULL
                    AND textSelections IS NOT NULL
                    AND scrollRatioX IS NOT NULL
                    AND scrollRatioY IS NOT NULL
                    AND textAmount IS NOT NULL
                    AND area IS NOT NULL
                """)
            try db.drop(table: "LongTermUrlScore")
            try db.rename(table: "newLongTermUrlScore", to: "LongTermUrlScore")
        }

        migrator.registerMigration("addIsPinnedToDailyUrlScores") { db in
            try db.alter(table: "DailyUrlScore") { table in
                table.add(column: "isPinned", .boolean).defaults(to: false)
            }
        }

        TabGroupsStore.registerMigration(with: &migrator)

        #if DEBUG
        // Speed up development by nuking the database when migrations change
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        try checkCurrentMigrationStatus(dbReader: dbReader)

        if migrate {
            try self.migrate()
        }

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
    private var migrator = DatabaseMigrator()

    func migrate(upTo: String? = nil) throws {
        if let upTo = upTo {
            try migrator.migrate(dbWriter, upTo: upTo)
        } else {
            try migrator.migrate(dbWriter)
        }
    }
    private func checkCurrentMigrationStatus(dbReader: DatabaseReader) throws {
        try dbReader.read { db in
            if try migrator.hasBeenSuperseded(db) {
                Logger.shared.logError("GRDB migration status is ahead of registred migrations.", category: .database)
                UserAlert.showError(message: "You need to update to the latest version of Beam",
                                    informativeText: "The database was created by a more advanced version of Beam and this version cannot read it.",
                                    buttonTitle: "Exit now")
                AppDelegate.main.skipTerminateMethods = true
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Database Access: Writes

extension GRDBDatabase {
    // MARK: - BeamNote / BeamElement
    func append(note: BeamNote) throws {
        // only reindex note if needed:
        let pivotDate = lastIndexingFor(note: note)
        guard note.updateDate > pivotDate else { return }

        let databaseId = note.databaseId?.uuidString ?? DatabaseManager.defaultDatabase.id.uuidString
        let noteTitle = note.title
        let noteIdStr = note.id.uuidString
        let records = note.allTextElements.map { BeamElementRecord(title: noteTitle, text: $0.text.text, uid: $0.id.uuidString, noteId: noteIdStr, databaseId: databaseId) }
        let links = note.internalLinks

        BeamNote.indexingQueue.addOperation {
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
            try MnemonicRecord.deleteAll(db)
            try DomainPath0TreeStats.deleteAll(db)
            try DomainPath0ReadingDay.deleteAll(db)
            try BrowsingTreeStats.deleteAll(db)
            try TabPinSuggestion.deleteAll(db)
            try DailyURLScore.deleteAll(db)
            try Link.deleteAll(db)
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
    func _insertHistoryUrl(urlId: UUID, url: String, aliasDomain: String?, title: String, content: String?) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: """
                INSERT OR REPLACE INTO historyUrlRecord (urlId, url, alias_domain, title, content, last_visited_at)
                VALUES (?, ?, ?, ?, ?, datetime('now'))
                """,
                arguments: [urlId, url, aliasDomain ?? "", title, content ?? ""])
        }
    }

    // MARK: - MnemonicRecord

    /// Register the URL in the history table associated with a `last_visited_at` timestamp.
    /// - Parameter urlId: URL identifier from the LinkStore
    /// - Parameter url: URL to the page
    /// - Parameter title: Title of the page indexed in FTS
    /// - Parameter text: Content of the page indexed in FTS
    func insertMnemonic(text: String, url: UUID) throws {
        try dbWriter.write { db in
            try MnemonicRecord(text: text.lowercased(), url: url, lastVisitedAt: BeamDate.now).insert(db)
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

    func getFrecencies(urlIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyUrlRecord] {
        var scores = [UUID: FrecencyUrlRecord]()
        try? dbReader.read { db in
            return try FrecencyUrlRecord
                .filter(urlIds.contains(FrecencyUrlRecord.Columns.urlId))
                .filter(FrecencyNoteRecord.Columns.frecencyKey == paramKey)
                .fetchCursor(db)
                .forEach { scores[$0.urlId] = $0 }
        }
        return scores
    }
    func getFrecencyScoreValues(urlIds: [UUID], paramKey: FrecencyParamKey) -> [UUID: Float] {
        let scores = getFrecencies(urlIds: urlIds, paramKey: paramKey)
        return scores.mapValues { $0.frecencySortScore }
    }
    func clearUrlFrecencies() throws {
        _ = try dbWriter.write { db in
            try FrecencyUrlRecord.deleteAll(db)
        }
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
    func fetchNoteFrecencies(noteId: UUID) -> [FrecencyNoteRecord] {
        do {
            return try dbReader.read { db in
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

    func clearNoteFrecencies() throws {
        _ = try dbWriter.write { db in
            try FrecencyNoteRecord.deleteAll(db)
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

    func save(scores: [LongTermUrlScore]) throws {
        try dbWriter.write { db in
            for score in scores {
                try score.save(db)
            }
        }
    }
    func clearLongTermScores() throws {
        _ = try dbWriter.write { db in
            try LongTermUrlScore.deleteAll(db)
        }

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
    func browsingTreeProcessingStatuses(ids: [UUID]) -> [UUID: BrowsingTreeRecord.ProcessingStatus] {
        (try? dbReader.read { (db) -> [UUID: BrowsingTreeRecord.ProcessingStatus]? in
            let cursor = try BrowsingTreeRecord.fetchCursor(db).map { ($0.rootId, $0.processingStatus) }
            let statuses: [UUID: BrowsingTreeRecord.ProcessingStatus]? = try? Dictionary(uniqueKeysWithValues: cursor)
            return statuses
        }) ?? [UUID: BrowsingTreeRecord.ProcessingStatus]()
    }
    func update(record: BrowsingTreeRecord, status: BrowsingTreeRecord.ProcessingStatus) {
        var updatedRecord = record
        updatedRecord.processingStatus = status
        do {
            _ = try dbWriter.write { db in
                try updatedRecord.updateChanges(db, from: record)
            }
        } catch {
            Logger.shared.logInfo("Couldn't update tree record id: \(record.rootId) \(error)", category: .browsingTreeNetwork)
        }

    }
    func softDeleteBrowsingTrees(olderThan days: Int, maxRows: Int) throws {
        let now = BeamDate.now
        let timeCond = BrowsingTreeRecord.Columns.rootCreatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = BrowsingTreeRecord.select(BrowsingTreeRecord.Columns.rootId)
            .order(BrowsingTreeRecord.Columns.rootCreatedAt.desc)
            .limit(maxRows)

        try _ = dbWriter.write { db in
            try BrowsingTreeRecord
                .filter(timeCond || !rankSubQuery.contains(BrowsingTreeRecord.Columns.rootId))
                .updateAll(db,
                           BrowsingTreeRecord.Columns.deletedAt.set(to: now),
                           BrowsingTreeRecord.Columns.updatedAt.set(to: now),
                           BrowsingTreeRecord.Columns.flattenedData.set(to: nil)
                )
        }
    }
    // MARK: - LinkStore

    func checkAndRepairLinksIntegrity() {
        try? dbWriter.write { db in
            let linkContentTable = Link.FTS.databaseTableName
            typealias DBError = GRDB.DatabaseError
            do {
                try db.execute(sql: "INSERT INTO \(linkContentTable)(\(linkContentTable)) VALUES('integrity-check')")
            } catch {
                Logger.shared.logWarning("Integrity issue detected on '\(linkContentTable)' table", category: .database)
                EventsTracker.sendManualReport(forError: error)
                if let dbError = error as? GRDB.DatabaseError,
                   [DBError.SQLITE_CORRUPT, DBError.SQLITE_CORRUPT_VTAB, DBError.SQLITE_CORRUPT_INDEX].map({ $0.primaryResultCode }).contains(dbError.resultCode) {
                    Logger.shared.logWarning("Rebuilding '\(linkContentTable)' table", category: .database)
                    do {
                        try db.execute(sql: "INSERT INTO \(linkContentTable)(\(linkContentTable)) VALUES('rebuild')")
                    } catch {
                        EventsTracker.sendManualReport(forError: error)
                    }
                }
            }
        }
    }

    func getLinks(matchingUrl url: String) -> [UUID: Link] {
        var matchingLinks = [UUID: Link]()
        try? dbReader.read { db in
            try Link.filter(Column("url").like("%\(url)%"))
                .fetchAll(db)
                .forEach { matchingLinks[$0.id] = $0 }
        }
        return matchingLinks
    }

    public struct LinkWithDestination: FetchableRecord {
        var link: Link
        var destinationLink: Link?

        init(row: Row) {
            link = Link(row: row)
            destinationLink = row["destinationLink"]
        }
    }

    func getTopScoredLinks(matchingUrl url: String, frecencyParam: FrecencyParamKey, limit: Int = 10) -> [LinkSearchResult] {
        let destinationAlias = TableAlias()
        let association = Link.destinationLink.aliased(destinationAlias)
        let query = Link
            .filter(Column("url").like("%.\(url)%") || Column("url").like("%/\(url)%"))
            .including(optional: association)
            .order((destinationAlias["frecencyVisitSortScore"] ?? Link.Columns.frecencyVisitSortScore).desc)
            .limit(limit)

        return (try? dbReader.read { db in
            let links = try LinkWithDestination.fetchAll(db, query)
            return links.map { record in
                LinkSearchResult(title: record.link.title,
                                 url: record.link.url,
                                 frecencySortScore: record.destinationLink?.frecencyVisitSortScore ?? record.link.frecencyVisitSortScore,
                                 destinationURL: record.destinationLink?.url)
            }
        }) ?? []
    }

    func getOrCreateId(for url: String, title: String?, content: String?, destination: String?) -> UUID {
        (try? dbReader.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)?.id
        }) ?? visit(url: url, title: title, content: content, destination: destination).id
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
    func getLinks(ids: [UUID]) throws -> [UUID: Link] {
        try dbReader.read { db in
            let cursor = try Link
                .filter(ids.contains(Link.Columns.id))
                .fetchCursor(db)
                .map { ($0.id, $0) }
            return try Dictionary(uniqueKeysWithValues: cursor)
        }
    }

    func linkFor(url: String) -> Link? {
        try? dbReader.read { db in
            try Link.filter(Column("url") == url).fetchOne(db)
        }
    }

    @discardableResult
    func visit(url: String, title: String? = nil, content: String?, destination: String?) -> Link {
        guard var link = linkFor(url: url) else {
            // The link doesn't exist, create it and return the id
            var link = Link(url: url, title: title, content: content)
            link.setDestination(destination)
            _ = try? dbWriter.write { db in
                try link.insert(db)
            }
            return link
        }

        // otherwise let's update the title and the updatedAt
        if title?.isEmpty == false {
            link.title = title
        }
        link.content = content
        link.setDestination(destination)
        link.updatedAt = BeamDate.now

        _ = try? dbWriter.write { db in
            try link.update(db, columns: [Column("updateAt"), Column("title"), Column("content"), Column("destination")])
        }
        return link
    }
    func updateLinkFrecency(id: UUID, lastAccessAt: Date, score: Float, sortScore: Float) {
        guard var link = linkFor(id: id) else { return }
        link.frecencyVisitLastAccessAt = lastAccessAt
        link.frecencyVisitScore = score
        link.frecencyVisitSortScore = sortScore
        link.updatedAt = BeamDate.now

        let updateColumns = [
            Column("updatedAt"),
            Column("frecencyVisitLastAccessAt"),
            Column("frecencyVisitScore"),
            Column("frecencyVisitSortScore")
        ]
        _ = try? dbWriter.write { db in
            try link.update(db, columns: updateColumns)
        }
    }

    func updateLinkFrecencies(scores: [FrecencyScore]) {
        let q = """
                UPDATE link
                SET
                    updatedAt = :updatedAt,
                    frecencyVisitLastAccessAt = :lastAccessAt,
                    frecencyVisitScore = :score,
                    frecencyVisitSortScore = :sortScore
                WHERE id = :id
                """
        let now = BeamDate.now
        do {
            _ = try dbWriter.write { db in
                for score in scores {
                    let arguments: StatementArguments = [
                        "updatedAt": now,
                        "lastAccessAt": score.lastTimestamp,
                        "score": score.lastScore,
                        "sortScore": score.sortValue,
                        "id": score.id
                    ]
                    try db.execute(sql: q, arguments: arguments)
                }
            }
        } catch {
            Logger.shared.logError("Couldn't update link frecencies: \(error)", category: .database)
        }
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

    func getMnemonic(text: String) -> URL? {
        guard let mnemonic = try? dbReader.read({ try MnemonicRecord.filter(MnemonicRecord.Columns.text == text.lowercased()).fetchOne($0) }),
        let link = LinkStore.shared.linkFor(id: mnemonic.url)?.url,
            let url = URL(string: link) else {
                return nil
            }
        return url
    }

    func insertOrIgnore(links: [Link]) throws {
        try dbWriter.write { db in
            for var link in links where try !link.exists(db) {
                try link.insert(db)
            }
        }
    }

    // Search History and Aliases:
    public struct LinkSearchResult {
        let title: String?
        let url: String
        let frecencySortScore: Float?
        var destinationURL: String?
    }

    public struct LinkWithFrecency: FetchableRecord {
        var link: Link
        var frecency: FrecencyUrlRecord?

        init(row: Row) {
            link = Link(row: row)
            frecency = row[Link.frecencyForeign]
        }
    }

    /// Perform a history search query.
    /// - Parameter prefixLast: when enabled the last token is prefix matched.
    /// - Parameter enabledFrecencyParam: select the frecency parameter to use to sort results.
    func searchLink(query: String,
                    prefixLast: Bool = true,
                    enabledFrecencyParam: FrecencyParamKey? = nil,
                    limit: Int = 10,
                    completion: @escaping (Result<[LinkSearchResult], Error>) -> Void) {
        guard var pattern = FTS3Pattern(matchingAllTokensIn: query) else {
            completion(.failure(GRDBDatabase.ReadError.invalidFTSPattern))
            return
        }
        if prefixLast {
            guard let prefixLastPattern = try? FTS3Pattern(rawPattern: pattern.rawPattern + "*") else {
                completion(.failure(GRDBDatabase.ReadError.invalidFTSPattern))
                return
            }
            pattern = prefixLastPattern
        }

        dbReader.asyncRead { (dbResult: Result<GRDB.Database, Error>) in
            do {
                let joint = PreferencesManager.includeHistoryContentsInOmniBox ? Link.contentAssociation.matching(pattern) : Link.contentAssociation.filter(Column("title").match(pattern))

                let db = try dbResult.get()
                let destinationAlias = TableAlias()
                let association = Link.destinationLink.aliased(destinationAlias)
                let request = Link
                    .joining(required: joint)
                    .including(optional: association)
                    .order((destinationAlias["frecencyVisitSortScore"] ?? Link.Columns.frecencyVisitSortScore).desc)
                    .limit(limit)

                let results = try request
                    .asRequest(of: LinkWithDestination.self)
                    .fetchAll(db)
                    .map { record -> LinkSearchResult in
                        Logger.shared.logDebug("Found \(record.link.url) - with frecency: \(String(describing: record.link.frecencyVisitSortScore))", category: .search)
                        return LinkSearchResult(
                            title: record.link.title,
                            url: record.link.url,
                            frecencySortScore: record.destinationLink?.frecencyVisitSortScore ?? record.link.frecencyVisitSortScore,
                            destinationURL: record.destinationLink?.url
                        )
                    }
                completion(.success(results))
            } catch {
                Logger.shared.logError("history search failure: \(error)", category: .search)
                completion(.failure(error))
            }
        }
    }
    // MARK: - DomainPath0ReadingDay
    func addDomainPath0ReadingDay(domainPath0: String, date: Date) throws {
        guard let truncatedDate = date.utcDayTruncated else { return }
        let record = DomainPath0ReadingDay(domainPath0: domainPath0, readingDay: truncatedDate)
        try dbWriter.write { db in
            try record.insert(db)
        }
    }
    var domainPath0MinReadDay: Date? {
        do {
            return try dbReader.read { db in
                try Date.fetchOne(db, DomainPath0ReadingDay.select(min(DomainPath0ReadingDay.Columns.readingDay)))
            }
        } catch {
            Logger.shared.logError("Couldn't fetch min domainPath0 min read day", category: .database)
            return nil
        }
    }

    func cleanDomainPath0ReadingDay(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = DomainPath0ReadingDay.Columns.readingDay <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = DomainPath0ReadingDay
            .select(DomainPath0ReadingDay.Columns.id)
            .order(DomainPath0ReadingDay.Columns.readingDay.desc)
            .limit(maxRows)
        try _ = dbWriter.write { db in
            try DomainPath0ReadingDay
                .filter(timeCond || !rankSubQuery.contains(DomainPath0ReadingDay.Columns.id))
                .deleteAll(db)
        }
    }
    func countDomainPath0ReadingDay(domainPath0: String) throws -> Int {
        try dbReader.read { db in
            try DomainPath0ReadingDay.filter(DomainPath0ReadingDay.Columns.domainPath0 == domainPath0).fetchCount(db)
        }
    }
    // MARK: - DomainPath0TreeStat
    func getDomainPath0TreeStat(domainPath0: String, treeId: UUID) throws -> DomainPath0TreeStats? {
        try dbReader.read { db in
            try DomainPath0TreeStats
                .filter(DomainPath0TreeStats.Columns.domainPath0 == domainPath0)
                .filter(DomainPath0TreeStats.Columns.treeId == treeId)
                .fetchOne(db)
        }
    }

    func updateDomainPath0TreeStat(domainPath0: String, treeId: UUID, readingTime: Double) throws {
        var existingRecord = try getDomainPath0TreeStat(domainPath0: domainPath0, treeId: treeId)
        existingRecord?.updatedAt = BeamDate.now
        var recordToSave = existingRecord ?? DomainPath0TreeStats(treeId: treeId, domainPath0: domainPath0)
        recordToSave.readingTime += readingTime
        try dbWriter.write { db in
            try recordToSave.save(db)
        }
    }

    func cleanDomainPath0TreeStat(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = DomainPath0TreeStats.Columns.updatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = DomainPath0TreeStats.select(DomainPath0TreeStats.Columns.id)
            .order(DomainPath0TreeStats.Columns.updatedAt.desc)
            .limit(maxRows)
        try _ = dbWriter.write { db in
            try DomainPath0TreeStats
                .filter(timeCond || !rankSubQuery.contains(DomainPath0TreeStats.Columns.id))
                .deleteAll(db)
        }
    }
    // MARK: - BrowsingTreeStats
    func getBrowsingTreeStats(treeId: UUID) throws -> BrowsingTreeStats? {
        try dbReader.read { db in
            try BrowsingTreeStats.fetchOne(db, id: treeId)
        }
    }
    func updateBrowsingTreeStats(treeId: UUID, changes: (BrowsingTreeStats) -> Void ) throws {
        try dbWriter.write {db in
            let existingStats = try BrowsingTreeStats.fetchOne(db, id: treeId)
            existingStats?.updatedAt = BeamDate.now
            let stats = existingStats ?? BrowsingTreeStats(treeId: treeId)
            changes(stats)
            try stats.save(db)
        }
    }
    func cleanBrowsingTreeStats(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = BrowsingTreeStats.Columns.updatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = BrowsingTreeStats.select(BrowsingTreeStats.Columns.treeId)
            .order(BrowsingTreeStats.Columns.updatedAt.desc)
            .limit(maxRows)

        try _ = dbWriter.write { db in
            try BrowsingTreeStats
                .filter(timeCond || !rankSubQuery.contains(BrowsingTreeStats.Columns.treeId))
                .deleteAll(db)
        }
    }
    // MARK: - TabPinSuggestions
    func addTabPinSuggestion(domainPath0: String) throws {
        let suggestion = TabPinSuggestion(domainPath0: domainPath0)
        try dbWriter.write { db in
            try suggestion.insert(db)
        }
    }
    var tabPinSuggestionCount: Int {
        (try? dbReader.read { db in
            try TabPinSuggestion.fetchCount(db)
        }) ?? 0
    }
    func alreadyPinTabSuggested(domainPath0: String) throws -> Bool {
        try dbReader.read { db in
            try TabPinSuggestion.filter(TabPinSuggestion.Columns.domainPath0 == domainPath0).fetchCount(db) > 0
        }
    }
    func cleanTabPinSuggestions() throws {
        try _ = dbWriter.write { db in
            try TabPinSuggestion.deleteAll(db)
        }
    }

    func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float,
                                       dayRange: Int, maxRows: Int) throws -> [ScoredDomainPath0] {
        let rightTimeBound = BeamDate.now
        let leftTimeBound = rightTimeBound - Double(dayRange * 24 * 60 * 60)
        let query: SQLRequest<ScoredDomainPath0> = SQLRequest("""
            WITH distinctReadDays AS (
              SELECT
                domainPath0,
                COUNT(1) readDayCount
              FROM DomainPath0ReadingDay d
              WHERE readingDay BETWEEN \(leftTimeBound) AND \(rightTimeBound)
              GROUP BY domainPath0
              HAVING readDayCount >= \(minDayCount)
            ),

            domainTreeStats AS (
              SELECT
                domainPath0,
                SUM(dt.readingTime) as readingTime,
                SUM(t.readingTime) as treeReadingTime,
                AVG(t.lifeTime) as treeLifetime
              FROM domainPath0TreeStats dt
              JOIN browsingTreeStats t ON dt.treeId = t.treeId
              WHERE dt.updatedAt BETWEEN \(leftTimeBound) AND \(rightTimeBound)
              GROUP BY dt.domainPath0
              HAVING
                SUM(t.readingTime) > 0
                AND SUM(dt.readingTime) / SUM(t.readingTime) >= \(minTabReadingTimeShare)
                AND AVG(t.lifeTime) >= \(minAverageTabLifetime)
            )

            SELECT d.domainPath0, (d.readDayCOunt * dt.readingTime / dt.treeReadingTime * dt.treeLifeTime) AS score
            FROM distinctReadDays d
            JOIN domainTreeStats dt ON d.domainPath0 = dt.domainPath0
            ORDER BY (d.readDayCOunt * dt.readingTime / dt.treeReadingTime * dt.treeLifeTime) DESC
            LIMIT \(maxRows)
        """
        )

        return try dbReader.read { db in
            try ScoredDomainPath0.fetchAll(db, query)
        }
    }
// MARK: - DailyUrlScore
    //day in format "YYYY-MM-DD"
    func updateDailyUrlScore(urlId: UUID, day: String, changes: (DailyURLScore) -> Void ) {
        do {
            try dbWriter.write { db in
                let fetched = try? DailyURLScore
                    .filter(DailyURLScore.Columns.urlId == urlId)
                    .filter(DailyURLScore.Columns.localDay == day)
                    .fetchOne(db)
                let score = fetched ?? DailyURLScore(urlId: urlId, localDay: day)
                changes(score)
                score.updatedAt = BeamDate.now
                try score.save(db)
            }
        } catch {
            Logger.shared.logError("Couldn't update url daily score for \(urlId) at \(day)", category: .database)
        }
    }

    //day in format "YYYY-MM-DD"
    func getDailyUrlScores(day: String) -> [UUID: DailyURLScore] {
        do {
            return try dbReader.read { db in
                let cursor = try DailyURLScore
                        .filter(DailyURLScore.Columns.localDay == day)
                        .fetchCursor(db)
                        .map { ($0.urlId, $0) }
                return try Dictionary(uniqueKeysWithValues: cursor)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch daily url scores at \(day): \(error)", category: .database)
            return [:]
        }
    }

    //day in format "YYYY-MM-DD"
    func clearDailyUrlScores(toDay day: String? = nil) throws {
        try dbWriter.write { db in
            if let day = day {
                let timeCond = DailyURLScore.Columns.localDay <= day
                try DailyURLScore.filter(timeCond).deleteAll(db)
            } else {
                try DailyURLScore.deleteAll(db)
            }
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

// MARK: - Tab Group
// Temporarily here while the "move to GRDB" is ongoing
extension GRDBDatabase {
    func getTabGroups(ids: [UUID]) -> [TabGroupBeamObject] {
        do {
            return try dbReader.read { db in
                return try TabGroupBeamObject
                    .filter(ids.contains(TabGroupBeamObject.Columns.id))
                    .order(TabGroupBeamObject.Columns.updatedAt.desc)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups for ids '\(ids)'. \(error)", category: .database)
            return []
        }
    }

    func getTabGroups(matchingTitle title: String) -> [TabGroupBeamObject] {
        let query = title.lowercased()
        do {
            return try dbReader.read { db in
                return try TabGroupBeamObject
                    .filter(TabGroupBeamObject.Columns.title.like("%\(query)%"))
                    .order(TabGroupBeamObject.Columns.updatedAt.desc)
                    .limit(10)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups matching '\(query)'. \(error)", category: .database)
            return []
        }
    }

    func saveTabGroups(_ groups: [TabGroupBeamObject]) {
        do {
            try dbWriter.write { db in
                try groups.forEach { group in
                    var group = group
                    if group.pages.isEmpty {
                        try group.delete(db)
                    } else {
                        group.updatedAt = BeamDate.now
                        try group.save(db)
                    }
                }
            }
        } catch {
            Logger.shared.logError("Couldn't save tab groups", category: .database)
        }
    }

    func deleteAllTabGroups() {
        do {
            _ = try dbWriter.write { db in
                try TabGroupBeamObject.deleteAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't delete all tab groups", category: .database)
        }

    }
}
