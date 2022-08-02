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
    case cantSavePassword(errorMsg: String)
    case cantDeletePassword(errorMsg: String)
    case errorFetchingPassword(errorMsg: String)
    case errorSearchingPassword(errorMsg: String)
}

struct RemotePasswordRecord {
    internal static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString

    var uuid: UUID = .null
    var entryId: String
    var hostname: String
    var host: String? // TODO: Remove the support of old keys
    var name: String? // TODO: Remove the support of old keys
    var username: String
    var password: String
    var createdAt: Date
    var updatedAt: Date
    var usedAt: Date
    var deletedAt: Date?
    var privateKeySignature: String?
}

extension RemotePasswordRecord: BeamObjectProtocol {
    static let beamObjectType = BeamObjectObjectType.password

    var beamObjectId: UUID {
        get { uuid }
        set { uuid = newValue }
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
        case usedAt
        case deletedAt
        case privateKeySignature
    }

    func copy() -> Self {
        self
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
        usedAt = try container.decodeIfPresent(Date.self, forKey: .usedAt) ?? BeamDate.now
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        privateKeySignature = try? container.decode(String.self, forKey: .privateKeySignature)
    }
}

struct LocalPasswordRecord {
    internal static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString

    var uuid: UUID = .null
    var entryId: String
    var hostname: String
    var username: String
    var password: String
    var createdAt: Date
    var updatedAt: Date
    var usedAt: Date
    var deletedAt: Date?
    var privateKeySignature: String?
}

extension LocalPasswordRecord {
    func copy() -> Self {
        self
    }
}

extension LocalPasswordRecord: Equatable { }

extension LocalPasswordRecord: TableRecord {
    static let databaseTableName = "passwordRecord"

    enum Columns: String, ColumnExpression {
        case uuid, entryId, hostname, username, password, createdAt, updatedAt, usedAt, deletedAt, privateKeySignature
    }
}

// Fetching
extension LocalPasswordRecord: FetchableRecord {
    init(row: Row) {
        uuid = row[Columns.uuid]
        entryId = row[Columns.entryId]
        hostname = row[Columns.hostname]
        username = row[Columns.username]
        password = row[Columns.password]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        usedAt = row[Columns.usedAt]
        deletedAt = row[Columns.deletedAt]
        privateKeySignature = row[Columns.privateKeySignature]
    }
}

// Persisting
extension LocalPasswordRecord: MutablePersistableRecord {
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
        container[Columns.usedAt] = usedAt
        container[Columns.deletedAt] = deletedAt
        container[Columns.privateKeySignature] = privateKeySignature
    }
}

class PasswordsDB: GRDBHandler, PasswordStore, BeamManager, LegacyAutoImportDisabler {
    static var id = UUID()
    static var name = "PasswordDBManager"
    weak var holder: BeamManagerOwner?
    var grdbStore: GRDBStore

    override var tableNames: [String] { [PasswordsDB.tableName] }

    static let tableName = "passwordRecord"

    //swiftlint:disable:next function_body_length
    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        self.grdbStore = store
        try super.init(store: store)
    }

    override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("passwordTableCreation") { db in
            try db.create(table: PasswordsDB.tableName, ifNotExists: true) { table in
                table.column("uuid", .text).notNull().primaryKey().unique()
                table.column("entryId", .text).notNull().unique()
                table.column("hostname", .text).notNull().indexed()
                table.column("username", .text).notNull()
                table.column("password", .text).notNull()
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("privateKeySignature", .text)
            }
        }

        migrator.registerMigration("passwordRecency") { db in
            try db.alter(table: PasswordsDB.tableName) { table in
                table.add(column: "usedAt", .datetime).notNull().defaults(sql: "\"1970-01-01\"")
            }
        }
    }

    private func id(for hostname: String, and username: String) -> String {
        return PasswordManagerEntry(minimizedHost: hostname, username: username).id
    }

    private func credentials(for passwordRecords: [LocalPasswordRecord]) -> [Credential] {
        passwordRecords.map { Credential(username: $0.username, password: $0.password) }
    }

    func entries(for host: String, options: PasswordManagerHostLookupOptions) throws -> [LocalPasswordRecord] {
        var allEntries: [LocalPasswordRecord]
        if options.contains(.subdomains) {
            allEntries = try entriesWithSubdomains(for: host)
        } else {
            allEntries = try entries(for: host)
        }
        if options.contains(.parentDomains) {
            var components = host.components(separatedBy: ".")
            var parentHosts = [String]()
            while components.count > 2 {
                components.removeFirst()
                parentHosts.append(components.joined(separator: "."))
            }
            for parentHost in parentHosts {
                let entries = try entries(for: parentHost)
                allEntries += entries
            }
        }
        return allEntries.sorted { $0.usedAt > $1.usedAt }
    }

    internal func entries(for hostname: String) throws -> [LocalPasswordRecord] {
        do {
            return try read { db in
                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.hostname == hostname && LocalPasswordRecord.Columns.deletedAt == nil)
                    .order(LocalPasswordRecord.Columns.usedAt.desc, LocalPasswordRecord.Columns.username)
                    .fetchAll(db)
                return passwords
            }
        } catch let error {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func entriesWithSubdomains(for hostname: String) throws -> [LocalPasswordRecord] {
        do {
            return try read { db in
                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.hostname == hostname || LocalPasswordRecord.Columns.hostname.like("%.\(hostname)"))
                    .filter(LocalPasswordRecord.Columns.deletedAt == nil)
                    .order(LocalPasswordRecord.Columns.usedAt.desc, LocalPasswordRecord.Columns.username)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func find(_ searchString: String) throws -> [LocalPasswordRecord] {
        do {
            return try read { db in
                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.hostname.like("%\(searchString)%") && LocalPasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorSearchingPassword(errorMsg: error.localizedDescription)

        }
    }

    func fetchAll() throws -> [LocalPasswordRecord] {
        do {
            return try read { db in
                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.errorFetchingPassword(errorMsg: error.localizedDescription)
        }
    }

    func passwordRecord(hostname: String, username: String) throws -> LocalPasswordRecord? {
        do {
            return try read { db in
                try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.entryId == self.id(for: hostname, and: username) && LocalPasswordRecord.Columns.deletedAt == nil)
                    .fetchOne(db)
            }
        } catch let error {
            throw PasswordDBError.cantReadDB(errorMsg: error.localizedDescription)
        }
    }

    func save(hostname: String, username: String, encryptedPassword: String, privateKeySignature: String) throws -> LocalPasswordRecord {
        try save(hostname: hostname, username: username, encryptedPassword: encryptedPassword, privateKeySignature: privateKeySignature, uuid: nil)
    }

    func save(hostname: String, username: String, encryptedPassword: String, privateKeySignature: String, uuid: UUID? = nil) throws -> LocalPasswordRecord {
        do {
            return try write { db in
                var passwordRecord = LocalPasswordRecord(
                    uuid: uuid ?? UUID(),
                    entryId: self.id(for: hostname, and: username),
                    hostname: hostname,
                    username: username,
                    password: encryptedPassword,
                    createdAt: BeamDate.now,
                    updatedAt: BeamDate.now,
                    usedAt: BeamDate.now,
                    deletedAt: nil,
                    privateKeySignature: privateKeySignature)
                try passwordRecord.insert(db)
                return passwordRecord
            }
        } catch let error {
            throw PasswordDBError.cantSavePassword(errorMsg: error.localizedDescription)
        }
    }

    func save(passwords: [LocalPasswordRecord]) throws {
        try write { db in
            for password in passwords {
                var pass = password.copy()
                try pass.insert(db)
            }
        }
    }

    func update(record: LocalPasswordRecord, hostname: String, username: String, encryptedPassword: String, privateKeySignature: String, uuid: UUID? = nil) throws -> LocalPasswordRecord {
        do {
            return try write { db in
                var updatedRecord = record
                if let uuid = uuid {
                    updatedRecord.uuid = uuid
                }
                updatedRecord.entryId = self.id(for: hostname, and: username)
                updatedRecord.hostname = hostname
                updatedRecord.username = username
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

    func allRecords(_ updatedSince: Date? = nil) throws -> [LocalPasswordRecord] {
        try read { db in
            if let updatedSince = updatedSince {
                return try LocalPasswordRecord.filter(LocalPasswordRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try LocalPasswordRecord.fetchAll(db)
        }
    }

    func fetchWithId(_ id: UUID) throws -> LocalPasswordRecord? {
        try read { db in
            try LocalPasswordRecord.filter(LocalPasswordRecord.Columns.uuid == id).fetchOne(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [LocalPasswordRecord] {
        try read { db in
            try LocalPasswordRecord
                .filter(ids.contains(LocalPasswordRecord.Columns.uuid))
                .fetchAll(db)
        }
    }

    @discardableResult
    func markUsed(record: LocalPasswordRecord) throws -> LocalPasswordRecord {
        do {
            return try write { db in
                var updatedRecord = record
                updatedRecord.usedAt = BeamDate.now
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch {
            throw PasswordDBError.cantSavePassword(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func markDeleted(hostname: String, username: String) throws -> LocalPasswordRecord {
        do {
            return try write { db in
                if var password = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.entryId == self.id(for: hostname, and: username) && LocalPasswordRecord.Columns.deletedAt == nil)
                    .fetchOne(db) {
                    password.deletedAt = BeamDate.now
                    password.updatedAt = BeamDate.now
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
    func markAllDeleted() throws -> [LocalPasswordRecord] {
        do {
            return try write { db in
                let now = BeamDate.now
                try LocalPasswordRecord
                    .filter(Column("deletedAt") == nil)
                    .updateAll(db, Column("deletedAt").set(to: now), Column("updatedAt").set(to: now))

                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.deletedAt == now)
                    .fetchAll(db)
                // send to network
                return passwords
            }
        } catch {
            throw PasswordDBError.cantDeletePassword(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func deleteAll() throws -> [LocalPasswordRecord] {
        do {
            return try write { db in
                let passwords = try LocalPasswordRecord.fetchAll(db)
                try LocalPasswordRecord.deleteAll(db)
                return passwords
            }
        } catch {
            throw PasswordDBError.cantDeletePassword(errorMsg: error.localizedDescription)
        }
    }

    // Added for getting the credential for HTTP Basic / Digest auth. Not in the protocol for now…
    func credentials(for hostname: String, completion: @escaping ([Credential]) -> Void) {
        do {
            try read { db in
                let passwords = try LocalPasswordRecord
                    .filter(LocalPasswordRecord.Columns.hostname == hostname && LocalPasswordRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                completion(self.credentials(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while fetching password entries for \(hostname): \(error)", category: .passwordsDB)
        }
    }
}

extension BeamManagerOwner {
    var passwordDB: PasswordsDB? {
        try? manager(PasswordsDB.self)
    }
}

extension BeamData {
    var passwordDB: PasswordsDB? {
        currentAccount?.passwordDB
    }
}
