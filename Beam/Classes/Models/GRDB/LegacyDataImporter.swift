//
//  LegacyDataImporter.swift
//  Beam
//
//  Created by Sébastien Metrot on 20/06/2022.
//

import Foundation
import GRDB
import BeamCore

protocol LegacyAutoImportDisabler {
}

struct LegacyDataImporter: BeamDocumentSource {
    static var sourceId: String { "LegacyDataImporter" }
    var account: BeamAccount
    var database: BeamDatabase?
    var progressReport: (String) -> Void

    func grdbFileName() -> String {
        var suffix = "-\(Configuration.env)"
        if let jobId = ProcessInfo.processInfo.environment["CI_JOB_ID"] {
            Logger.shared.logDebug("Using Gitlab CI Job ID for GRDB sqlite file: \(jobId)", category: .search)

            suffix += "-\(jobId)"
        }

        return "GRDB\(suffix).sqlite"
    }

    func importAllFrom(path: String) throws {
        guard let cdPath = CoreDataManager.storeURLFromEnv()?.path else { throw BeamDataError.databaseNotFound }
        try importCoreDataDatabaseFrom(path: cdPath)
//        try importCoreDataDatabaseFrom(path: path + "Legacy.sqlite")
        try importGRDBDatabaseFrom(path: path + grdbFileName())
        try? importFilesFrom(path: path + "files.db")
        try? importPasswordsFrom(path: path + "passwords.db")
        try? importCreditCardsFrom(path: path + "creditCards.db")
        try? importContactsFrom(path: path + "contacts.db")
    }

    // MARK: GRDBDatabase
    func importGRDBDatabaseFrom(path: String) throws {
        Logger.shared.logInfo("Import GRDBDatase from \(path)", category: .database)
        var config = GRDB.Configuration()
        config.readonly = true
        let dbQueue = try DatabaseQueue(path: path, configuration: config)
        Logger.shared.logInfo("\tImport Account data", category: .database)
        importManagers(Array(account.managers.values), from: dbQueue, to: account.grdbStore.writer)

        Logger.shared.logInfo("\tImport Database data", category: .database)
        guard let currentDatabase = database ?? BeamData.shared.currentDatabase else {
            throw BeamDataError.databaseNotFound
        }
        importManagers(Array(currentDatabase.managers.values), from: dbQueue, to: currentDatabase.grdbStore.writer)
    }

    func importManagers(_ managers: [BeamManager], from: DatabaseReader, to: DatabaseWriter) {
        for manager in managers where manager as? LegacyAutoImportDisabler == nil {
            guard let handler = manager as? GRDBHandler else { continue }
            for tableName in handler.tableNames {
                try? copyTable(tableName, from: from, to: to)
            }
        }
    }

    func cdDate(_ value: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: value  - 3600)
    }

    func cdDateOpt(_ value: Double?) -> Date? {
        guard let value = value else { return nil }
        return Date(timeIntervalSinceReferenceDate: value  - 3600)
    }

    // MARK: CoreData
    func importCoreDataNotes(_ dbQueue: DatabaseReader) throws {
        progressReport("Import from legacy CoreData Notes")
        try dbQueue.read { db in
            do {
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZDOCUMENT")
                for row in rows {
                    do {
                        let id: UUID = row["ZID"]
                        let dbId: UUID = row["ZDATABASE_ID"]
                        let name: String = row["ZTITLE"]
                        let createdAt = cdDate(row["ZCREATED_AT"])
                        let updatedAt = cdDate(row["ZUPDATED_AT"])
                        let deletedAt = cdDateOpt(row["ZDELETED_AT"])
                        let type: Int16 = row["ZDOCUMENT_TYPE"]
                        let isPublic: Int64 = row["ZIS_PUBLIC"]
                        let journalDay: Int64 = row["ZJOURNAL_DAY"]
                        let data: Data? = row["ZDATA"]

                        progressReport("Import from legacy CoreData Note \(name)")

                        if let database = database ?? account.databases[dbId] {
                            if !database.isLoaded {
                                _ = try account.loadDatabase(database.id)
                            }
                            if deletedAt == nil, let data = data {
                                let document = BeamDocument(id: id, source: self, database: database, title: name, createdAt: createdAt, updatedAt: updatedAt, data: data, documentType: DocumentType(rawValue: type)!, version: 0, isPublic: isPublic != 0, journalDate: journalDay)
                                _ = try database.collection?.save(self, document, indexDocument: false)
                            }
                        }
                    } catch {
                        Logger.shared.logError("Unable to read or save document from coredata db into the new database: \(error)", category: .database)
                    }
                }
            } catch {
                Logger.shared.logError("Unable to read documents from coredata db: \(error)", category: .database)
                throw error
            }
        }
    }

    func importCoreDataDatabases(_ dbQueue: DatabaseReader) throws {
        progressReport("Import from legacy CoreData")
        if database == nil {
            try dbQueue.read { db in
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM ZDATABASE")
                for row in rows {
                    let id: UUID = row["ZID"]

                    guard account.databases[id] == nil else {
                        Logger.shared.logError("Database \(id) already exists. Skipping", category: .database)
                        continue
                    }
                    let name: String = row["ZTITLE"]
                    let createdAt = cdDate(row["ZCREATED_AT"])
                    let updatedAt = cdDate(row["ZUPDATED_AT"])
                    let deletedAt = cdDateOpt(row["ZDELETED_AT"])
                    let newDB = BeamDatabase(account: account, id: id, name: name)
                    newDB.createdAt = createdAt
                    newDB.updatedAt = updatedAt
                    newDB.deletedAt = deletedAt

                    try account.addDatabase(newDB)
                    _ = try account.loadDatabase(id)
                }
            }
        }
        try importCoreDataNotes(dbQueue)
    }

    func importCoreDataDatabaseFrom(path: String) throws {
        let dbQueue = try DatabaseQueue(path: path)
        try importCoreDataDatabases(dbQueue)
        try dbQueue.close()
    }

    // MARK: Files
    func importFilesFrom(path: String) throws {
        Logger.shared.logInfo("Import Files from \(path) into Database data", category: .database)
        guard let currentDatabase = database ?? BeamData.shared.currentDatabase else {
            throw BeamDataError.databaseNotFound
        }
        let dbQueue = try DatabaseQueue(path: path)
        try copyTable("contactRecord", from: dbQueue, to: currentDatabase.grdbStore.writer)
    }

    let columnSuppressor = [
        "BrowsingTreeRecord": ["previousChecksum"],
        "Link": ["previousChecksum"],
        "passwordRecord": ["previousChecksum"]
    ]

    func copyTable(_ tableName: String, from: DatabaseReader, to: DatabaseWriter) throws {
        // read the table description and the data
        progressReport("Import from legacy table \(tableName)")
        Logger.shared.logInfo("\t\tcopy table \(tableName)", category: .database)
        let (columns, rows): ([Row], [Row]) = try from.read { db in
            do {
                return (
                    try Row.fetchAll(db, sql: "SELECT name FROM PRAGMA_TABLE_INFO('\(tableName)')"),
                    try Row.fetchAll(db, sql: "SELECT * FROM \(tableName)")
                )
            } catch {
                Logger.shared.logError("Error while reading table '\(tableName)' from imported DB: \(error)", category: .database)
                throw error
            }
        }

        progressReport("Import \(rows.count) rows from legacy table \(tableName)")

        let supressedColumns = Set<String>(columnSuppressor[tableName] ?? [])
        let columnNames: [String] = columns.compactMap {
            let name: String = $0["name"]
            return supressedColumns.contains(name) ? nil : name
        }
        let columnsString = Array(repeating: "?", count: columnNames.count).joined(separator: ", ")
        Logger.shared.logInfo("\t\t\t\(rows.count) rows. Columns: \(columnNames.joined(separator: ", "))", category: .database)
        let statement = "INSERT INTO \(tableName) VALUES (\(columnsString))"
        var done = 0
        try to.writeWithoutTransaction({ db in
            try db.inTransaction {
                for row in rows {
                    let columnValues = columnNames.map { row[$0] }
                    progressReport("Import row \(done) / \(rows.count) from legacy table \(tableName)")

                    do {
                        try db.execute(sql: statement, arguments: StatementArguments(columnValues))
                    } catch {
                        Logger.shared.logError("Error while writing row into table '\(tableName)' from imported DB: \(error)", category: .database)
                        throw error
                    }

                    done += 1
                }
                return .commit
            }
        })
    }

    // MARK: Passwords
    func importPasswordsFrom(path: String) throws {
        Logger.shared.logInfo("Import Passwords from \(path) into Account data", category: .database)
        try copyTable("passwordRecord", from: try DatabaseQueue(path: path), to: account.grdbStore.writer)
        let before = try verifyPasswords(store: GRDBStore(writer: try DatabaseQueue(path: path)))
        let after = try verifyPasswords(store: account.grdbStore)
        if !before.isValid {
            Logger.shared.logError("Passwords DB was corrupted before migration: \(before.description)", category: .database)
        }
        if after != before {
            Logger.shared.logError("Passwords DB was changed during migration: \(after.description)", category: .database)
        }
    }

    private func verifyPasswords(store: GRDBStore) throws -> PasswordManager.SanityDigest {
        let passwordsDB = try PasswordsDB(holder: nil, store: store)
        let passwordManager = PasswordManager(overridePasswordDB: passwordsDB)
        return try passwordManager.sanityDigest()
    }

    // MARK: Credit cards
    func importCreditCardsFrom(path: String) throws {
        Logger.shared.logInfo("Credit Cards from \(path) into Account data", category: .database)
        try copyTable("creditCardRecord", from: try DatabaseQueue(path: path), to: account.grdbStore.writer)
    }

    // MARK: Contacts
    func importContactsFrom(path: String) throws {
        Logger.shared.logInfo("Contacts from \(path) into Account data", category: .database)
        try copyTable("contactRecord", from: try DatabaseQueue(path: path), to: account.grdbStore.writer)
    }
}
