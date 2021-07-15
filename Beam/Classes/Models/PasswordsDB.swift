//
//  PasswordsDB.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import BeamCore
import GRDB

struct PasswordRecord {
    internal static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.string

    var uuid: UUID
    var entryId: String
    var host: String
    var name: String
    var password: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var previousCheckSum: String?
}

extension PasswordRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case uuid, entryId, host, name, password, createdAt, updatedAt, deletedAt, previousChecksum
    }
}

// Fetching
extension PasswordRecord: FetchableRecord {
    init(row: Row) {
        uuid = row[Columns.uuid]
        entryId = row[Columns.entryId]
        host = row[Columns.host]
        name = row[Columns.name]
        password = row[Columns.password]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
        previousCheckSum = row[Columns.previousChecksum]
    }
}

// Persisting
extension PasswordRecord: MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.uuid] = uuid
        container[Columns.entryId] = entryId
        container[Columns.host] = host
        container[Columns.name] = name
        container[Columns.password] = password
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
        container[Columns.previousChecksum] = previousCheckSum
    }
}

class PasswordsDB: PasswordStore {
    static let tableName = "passwordRecord"
    var dbPool: DatabasePool

    init(path: String) throws {
        dbPool = try DatabasePool(path: path, configuration: GRDB.Configuration())

        var rows: [Row]?
        var migrator = DatabaseMigrator()

        migrator.registerMigration("saveOldData") { db in
            rows = try? Row.fetchAll(db, sql: "SELECT host, name, password FROM PasswordsRecord")
        }

        migrator.registerMigration("passwordTableCreation") { db in
            try db.create(table: PasswordsDB.tableName, ifNotExists: true) { table in
                table.column("uuid", .text).notNull().primaryKey().unique()
                table.column("entryId", .text).notNull().unique()
                table.column("host", .text).notNull().indexed()
                table.column("name", .text).notNull()
                table.column("password", .text).notNull()
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }
        }

        migrator.registerMigration("migrateOldData") { db in
            if let storedPasswords = rows {
                for password in storedPasswords {
                    var passwordRecord = PasswordRecord(
                        uuid: UUID(),
                        entryId: self.id(for: password["host"], and: password["name"]),
                        host: password["host"],
                        name: password["name"],
                        password: password["password"], createdAt: Date(), updatedAt: Date(), deletedAt: nil, previousCheckSum: nil)
                    try passwordRecord.insert(db)
                }
            }
        }
        try migrator.migrate(dbPool)
    }

    private func id(for host: String, and username: String) -> String {
        return PasswordManagerEntry(minimizedHost: host, username: username).id
    }

    private func entries(for passwordsRecord: [PasswordRecord]) -> [PasswordManagerEntry] {
        passwordsRecord.map { PasswordManagerEntry(minimizedHost: $0.host, username: $0.name) }
    }

    // PasswordStore
    func entries(for host: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host == host && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while fetching password entries for \(host): \(error)", category: .passwordsDB)
        }
    }

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host.like("%\(searchString)%") && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while searching password for \(searchString): \(error)", category: .passwordsDB)
        }
    }

    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch {
            Logger.shared.logError("Error while fetching all passwords: \(error)", category: .passwordsDB)
        }
    }

    func password(host: String, username: String, completion: @escaping (String?) -> Void) {
        do {
            try dbPool.read { db in
                guard let passwordRecord = try PasswordRecord
                        .filter(PasswordRecord.Columns.entryId == id(for: host, and: username) && PasswordRecord.Columns.deletedAt == nil)
                        .fetchOne(db) else {
                    completion(nil)
                    return
                }
                do {
                    let decryptedPassword = try EncryptionManager.shared.decryptString(passwordRecord.password)
                    completion(decryptedPassword)
                } catch {
                    Logger.shared.logError("Error while decrypting password for \(host) - \(username): \(error)", category: .encryption)
                }
            }
        } catch {
            Logger.shared.logError("Error while reading database for \(host) - \(username): \(error)", category: .passwordsDB)
        }
    }

    func save(host: String, username: String, password: String) {
        do {
            try dbPool.write { db in
                guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password) else {
                    Logger.shared.logError("Error while encrypting password for \(host) - \(username)", category: .encryption)
                    return
                }
                var passwordRecord = PasswordRecord(
                    uuid: UUID(),
                    entryId: id(for: host, and: username),
                    host: host,
                    name: username,
                    password: encryptedPassword, createdAt: Date(), updatedAt: Date(), deletedAt: nil, previousCheckSum: nil)
                try passwordRecord.insert(db)
            }
        } catch let error {
            Logger.shared.logError("Error while saving password for \(host): \(error)", category: .passwordsDB)
        }
    }

    func delete(host: String, username: String) {
        try? dbPool.write { db in
            if var password = try PasswordRecord
                .filter(PasswordRecord.Columns.entryId == id(for: host, and: username) && PasswordRecord.Columns.deletedAt == nil)
                .fetchOne(db) {
                password.deletedAt = Date()
                try password.update(db)
            }
        }
    }

    // Added only in the purpose of testing maybe will be added in the protocol if needed
    func deleteAll() {
        _ = try? dbPool.write { db in
            try PasswordRecord
                .filter(Column("deleteAt") == nil)
                .updateAll(db, Column("deleteAt").set(to: Date()))
        }
    }
}
