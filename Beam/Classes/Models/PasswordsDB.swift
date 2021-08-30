//
//  PasswordsDB.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import BeamCore
import GRDB

enum PasswordDBError: Error {
    case cantReadDB(errorMsg: String)
    case cantDecryptPassword(errorMsg: String)
    case cantSavePassword(errorMsg: String)
    case cantEncryptPassword
    case cantDeletePassword(errorMsg: String)
    case errorFetchingPassword(errorMsg: String)
    case errorSearchingPassword(errorMsg: String)
}

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
    var checksum: String?
    var privateKeySignature: String?
}

extension PasswordRecord: BeamObjectProtocol {
    static var beamObjectTypeName: String = "password"
    var beamObjectId: UUID {
        get { uuid }
        set { uuid = newValue }
    }
    var previousChecksum: String? {
        get { previousCheckSum }
        set { previousCheckSum = newValue }
    }

    // Used for encoding this into BeamObject
    enum CodingKeys: String, CodingKey {
        case uuid
        case entryId
        case host
        case name
        case password
        case createdAt
        case updatedAt
        case deletedAt
        case privateKeySignature
    }

    func copy() -> PasswordRecord {
        PasswordRecord(uuid: uuid,
                       entryId: entryId,
                       host: host, name: name,
                       password: password,
                       createdAt: createdAt,
                       updatedAt: updatedAt,
                       deletedAt: deletedAt,
                       previousCheckSum: previousCheckSum,
                       checksum: checksum,
                       privateKeySignature: privateKeySignature)
    }
}

extension PasswordRecord: Equatable { }

extension PasswordRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case uuid, entryId, host, name, password, createdAt, updatedAt, deletedAt, previousChecksum, privateKeySignature
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
        privateKeySignature = row[Columns.privateKeySignature]
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
        container[Columns.privateKeySignature] = privateKeySignature
    }
}

class PasswordsDB: PasswordStore {
    static let tableName = "passwordRecord"
    var dbPool: DatabasePool

    //swiftlint:disable:next function_body_length
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
                        password: password["password"],
                        createdAt: BeamDate.now,
                        updatedAt: BeamDate.now,
                        deletedAt: nil,
                        previousCheckSum: nil)
                    try passwordRecord.insert(db)
                }
            }
        }

        migrator.registerMigration("addPrivateKey") { db in
            try db.alter(table: PasswordsDB.tableName) { t in
                t.add(column: "privateKeySignature", .text)
            }

            if let storedPasswords = rows {
                for password in storedPasswords {
                    var encryptedPassword: String = ""
                    if let decryptedPassword = try EncryptionManager.shared.decryptString(password["password"]),
                       let newlyEncryptedPassword = try EncryptionManager.shared.encryptString(decryptedPassword) {
                        encryptedPassword = newlyEncryptedPassword
                    }

                    var passwordRecord = PasswordRecord(
                        uuid: password["uuid"],
                        entryId: password["entryId"],
                        host: password["host"],
                        name: password["name"],
                        password: encryptedPassword.isEmpty ? password["password"] : encryptedPassword,
                        createdAt: password["createdAt"],
                        updatedAt: password["updatedAt"],
                        deletedAt: password["deletedAt"],
                        previousCheckSum: password["previousCheckSum"],
                        privateKeySignature: encryptedPassword.isEmpty ? nil : try EncryptionManager.shared.privateKey().asString().SHA256())
                    try passwordRecord.insert(db)
                }
            }
        }
        try migrator.migrate(dbPool)
    }

    private func id(for host: String, and username: String) -> String {
        return PasswordManagerEntry(minimizedHost: host, username: username).id
    }

    private func credentials(for passwordsRecord: [PasswordRecord]) -> [Credential] {
        passwordsRecord.map { Credential(username: $0.name, password: $0.password) }
    }

    // PasswordStore
    func entries(for host: String, exact: Bool) throws -> [PasswordRecord] {
        guard !exact else {
            return try entries(for: host)
        }
        var components = host.components(separatedBy: ".")
        var parentHosts = [String]()
        while components.count > 2 {
            components.removeFirst()
            parentHosts.append(components.joined(separator: "."))
        }
        var allEntries = [PasswordRecord]()
        let entries = try entriesWithSubdomains(for: host)
        allEntries += entries
        for parentHost in parentHosts {
            let entries = try self.entries(for: parentHost)
            allEntries += entries
        }
        return allEntries
    }

    internal func entries(for host: String) throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host == host && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch let error {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func entriesWithSubdomains(for host: String) throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host == host || PasswordRecord.Columns.host.like("%.\(host)"))
                    .filter(PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func find(_ searchString: String) throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host.like("%\(searchString)%") && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorSearchingPassword(errorMsg: error.localizedDescription)

        }
    }

    func fetchAll() throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func password(host: String, username: String) throws -> String? {
        do {
            return try dbPool.read { db in
                guard let passwordRecord = try PasswordRecord
                        .filter(PasswordRecord.Columns.entryId == id(for: host, and: username) && PasswordRecord.Columns.deletedAt == nil)
                        .fetchOne(db) else {
                    return nil
                }
                do {
                    let decryptedPassword = try EncryptionManager.shared.decryptString(passwordRecord.password)
                    return decryptedPassword
                } catch let error {
                    throw PasswordDBError.cantDecryptPassword(errorMsg: error.localizedDescription)
                }
            }
        } catch let error {
            throw PasswordDBError.cantReadDB(errorMsg: error.localizedDescription)
        }
    }

    func save(host: String, username: String, password: String) throws -> PasswordRecord {
        try save(host: host, username: username, password: password, uuid: nil)
    }

    func save(host: String, username: String, password: String, uuid: UUID? = nil) throws -> PasswordRecord {
        do {
            return try dbPool.write { db in
                guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password) else {
                    throw PasswordDBError.cantEncryptPassword
                }
                let privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
                var passwordRecord = PasswordRecord(
                    uuid: uuid ?? UUID(),
                    entryId: id(for: host, and: username),
                    host: host,
                    name: username,
                    password: encryptedPassword,
                    createdAt: BeamDate.now,
                    updatedAt: BeamDate.now,
                    deletedAt: nil,
                    previousCheckSum: nil,
                    privateKeySignature: privateKeySignature)
                try passwordRecord.insert(db)
                return passwordRecord
            }
        } catch let error {
            throw PasswordDBError.cantSavePassword(errorMsg: error.localizedDescription)
        }
    }

    func save(passwords: [PasswordRecord]) throws {
        try dbPool.write { db in
            for password in passwords {
                var pass = password.copy()
                try pass.insert(db)
            }
        }
    }

    func allRecords() throws -> [PasswordRecord] {
        try dbPool.read { db in
            try PasswordRecord.fetchAll(db)
        }
    }

    func fetchWithId(_ id: UUID) throws -> PasswordRecord? {
        try dbPool.read { db in
            try PasswordRecord.filter(PasswordRecord.Columns.uuid == id).fetchOne(db)
        }
    }

    func delete(host: String, username: String) throws -> PasswordRecord {
        do {
            return try dbPool.write { db in
                if var password = try PasswordRecord
                    .filter(PasswordRecord.Columns.entryId == id(for: host, and: username) && PasswordRecord.Columns.deletedAt == nil)
                    .fetchOne(db) {
                    password.deletedAt = BeamDate.now
                    try password.update(db)
                    return password
                }
                throw PasswordDBError.cantDeletePassword(errorMsg: "Password not found!")
            }
        } catch let error {
            throw PasswordDBError.cantDeletePassword(errorMsg: error.localizedDescription)
        }
    }

    // Added only in the purpose of testing maybe will be added in the protocol if needed
    func deleteAll() throws -> [PasswordRecord] {
        do {
            return try dbPool.write { db in
                let now = BeamDate.now
                try PasswordRecord
                    .filter(Column("deletedAt") == nil)
                    .updateAll(db, Column("deletedAt").set(to: now))

                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.deletedAt == now)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.cantDeletePassword(errorMsg: error.localizedDescription)
        }
    }

    // Added for getting the credential for HTTP Basic / Digest auth. Not in the protocol for now…
    func credentials(for host: String, completion: @escaping ([Credential]) -> Void) {
        do {
            try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.host == host && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(credentials(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while fetching password entries for \(host): \(error)", category: .passwordsDB)
        }
    }
}
