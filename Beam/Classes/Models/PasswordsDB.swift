//
//  PasswordsDB.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//
// swiftlint:disable file_length

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

    var uuid: UUID = .null
    var entryId: String
    var hostname: String
    var host: String? // TODO: Remove the support of old keys
    var name: String? // TODO: Remove the support of old keys
    var username: String
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
        case entryId
        case hostname
        case host // TODO: Remove the support of old keys
        case username
        case name // TODO: Remove the support of old keys
        case password
        case createdAt
        case updatedAt
        case deletedAt
        case privateKeySignature
    }

    func copy() -> PasswordRecord {
        PasswordRecord(uuid: uuid,
                       entryId: entryId,
                       hostname: hostname, username: username,
                       password: password,
                       createdAt: createdAt,
                       updatedAt: updatedAt,
                       deletedAt: deletedAt,
                       previousCheckSum: previousCheckSum,
                       checksum: checksum,
                       privateKeySignature: privateKeySignature)
    }

    // TODO: Remove the support of old keys
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        entryId = try container.decode(String.self, forKey: .entryId)

        hostname = try (try? container.decode(String.self, forKey: .hostname)) ?? (try container.decode(String.self, forKey: .host))
        username = try (try? container.decode(String.self, forKey: .username)) ?? (try container.decode(String.self, forKey: .name))

        password = try container.decode(String.self, forKey: .password)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try? container.decode(Date.self, forKey: .deletedAt)
        privateKeySignature = try? container.decode(String.self, forKey: .privateKeySignature)
    }
}

extension PasswordRecord: Equatable { }

extension PasswordRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case uuid, entryId, hostname, username, password, createdAt, updatedAt, deletedAt, previousChecksum, privateKeySignature
    }
}

// Fetching
extension PasswordRecord: FetchableRecord {
    init(row: Row) {
        uuid = row[Columns.uuid]
        entryId = row[Columns.entryId]
        hostname = row[Columns.hostname]
        username = row[Columns.username]
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
        container[Columns.hostname] = hostname
        container[Columns.username] = username
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
                        hostname: password["host"],
                        username: password["name"],
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
                        hostname: password["host"],
                        username: password["name"],
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

        migrator.registerMigration("renameColumns") { db in
            try db.alter(table: PasswordsDB.tableName, body: { tb in
                tb.rename(column: "name", to: "username")
                tb.rename(column: "host", to: "hostname")
            })
        }

        migrator.registerMigration("saveAllPasswords") { db in
            if let rows = try? Row.fetchAll(db, sql: "SELECT * FROM \(PasswordsDB.tableName)") {
                var passwordRecords = [PasswordRecord]()
                for row in rows {
                    passwordRecords.append(PasswordRecord(row: row))
                }
                let beamObjectManager = BeamObjectManager()
                _ = try? beamObjectManager.saveToAPI(passwordRecords) { _ in }
            }
        }

        try migrator.migrate(dbPool)
    }

    private func id(for hostname: String, and username: String) -> String {
        return PasswordManagerEntry(minimizedHost: hostname, username: username).id
    }

    private func credentials(for passwordsRecord: [PasswordRecord]) -> [Credential] {
        passwordsRecord.map { Credential(username: $0.username, password: $0.password) }
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

    internal func entries(for hostname: String) throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.hostname == hostname && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch let error {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func entriesWithSubdomains(for hostname: String) throws -> [PasswordRecord] {
        do {
            return try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.hostname == hostname || PasswordRecord.Columns.hostname.like("%.\(hostname)"))
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
                    .filter(PasswordRecord.Columns.hostname.like("%\(searchString)%") && PasswordRecord.Columns.deletedAt == nil)
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

    func passwordRecord(hostname: String, username: String) throws -> PasswordRecord? {
        do {
            return try dbPool.read { db in
                try PasswordRecord
                    .filter(PasswordRecord.Columns.entryId == id(for: hostname, and: username) && PasswordRecord.Columns.deletedAt == nil)
                    .fetchOne(db)
            }
        } catch let error {
            throw PasswordDBError.cantReadDB(errorMsg: error.localizedDescription)
        }
    }

    func password(hostname: String, username: String) throws -> String? {
        guard let passwordRecord = try passwordRecord(hostname: hostname, username: username) else {
            return nil
        }
        do {
            let decryptedPassword = try EncryptionManager.shared.decryptString(passwordRecord.password)
            return decryptedPassword
        } catch let error {
            throw PasswordDBError.cantDecryptPassword(errorMsg: error.localizedDescription)
        }
    }

    func save(hostname: String, username: String, password: String) throws -> PasswordRecord {
        try save(hostname: hostname, username: username, password: password, uuid: nil)
    }

    func save(hostname: String, username: String, password: String, uuid: UUID? = nil) throws -> PasswordRecord {
        do {
            return try dbPool.write { db in
                guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password) else {
                    throw PasswordDBError.cantEncryptPassword
                }
                let privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
                var passwordRecord = PasswordRecord(
                    uuid: uuid ?? UUID(),
                    entryId: id(for: hostname, and: username),
                    hostname: hostname,
                    username: username,
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

    func update(record: PasswordRecord, password: String, uuid: UUID? = nil) throws -> PasswordRecord {
        do {
            return try dbPool.write { db in
                guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password) else {
                    throw PasswordDBError.cantEncryptPassword
                }
                let privateKeySignature = try EncryptionManager.shared.privateKey().asString().SHA256()
                var updatedRecord = record
                if let uuid = uuid {
                    updatedRecord.uuid = uuid
                }
                updatedRecord.password = encryptedPassword
                updatedRecord.updatedAt = BeamDate.now
                updatedRecord.privateKeySignature = privateKeySignature
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch let error {
            throw PasswordDBError.cantSavePassword(errorMsg: error.localizedDescription)
        }
    }

    func allRecords(_ updatedSince: Date? = nil) throws -> [PasswordRecord] {
        try dbPool.read { db in
            if let updatedSince = updatedSince {
                return try PasswordRecord.filter(PasswordRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try PasswordRecord.fetchAll(db)
        }
    }

    func fetchWithId(_ id: UUID) throws -> PasswordRecord? {
        try dbPool.read { db in
            try PasswordRecord.filter(PasswordRecord.Columns.uuid == id).fetchOne(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [PasswordRecord] {
        try dbPool.read { db in
            try PasswordRecord
                .filter(ids.contains(PasswordRecord.Columns.uuid))
                .fetchAll(db)
        }
    }

    @discardableResult
    func delete(hostname: String, username: String) throws -> PasswordRecord {
        do {
            return try dbPool.write { db in
                if var password = try PasswordRecord
                    .filter(PasswordRecord.Columns.entryId == id(for: hostname, and: username) && PasswordRecord.Columns.deletedAt == nil)
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

    @discardableResult
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

    @discardableResult
    func realDeleteAll() throws -> [PasswordRecord] {
        do {
            return try dbPool.write { db in
                let passwords = try PasswordRecord.fetchAll(db)
                try PasswordRecord.deleteAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.cantDeletePassword(errorMsg: error.localizedDescription)
        }
    }

    // Added for getting the credential for HTTP Basic / Digest auth. Not in the protocol for now…
    func credentials(for hostname: String, completion: @escaping ([Credential]) -> Void) {
        do {
            try dbPool.read { db in
                let passwords = try PasswordRecord
                    .filter(PasswordRecord.Columns.hostname == hostname && PasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(credentials(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while fetching password entries for \(hostname): \(error)", category: .passwordsDB)
        }
    }
}
