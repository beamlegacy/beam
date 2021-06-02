//
//  PasswordsDB.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/05/2021.
//

import Foundation
import BeamCore
import GRDB

struct PasswordsRecord {
    var id: Int64?
    var uuid: String
    var host: String
    var name: String
    var password: String
}

extension PasswordsRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, uuid, host, name, password
    }
}

// Fetching
extension PasswordsRecord: FetchableRecord {
    init(row: Row) {
        id = row[Columns.id]
        uuid = row[Columns.uuid]
        host = row[Columns.host]
        name = row[Columns.name]
        password = row[Columns.password]
    }
}

// Persisting
extension PasswordsRecord: MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.uuid] = uuid
        container[Columns.host] = host
        container[Columns.name] = name
        container[Columns.password] = password
    }

    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class PasswordsDB: PasswordStore {
    static let tableName = "PasswordsRecord"
    var dbQueue: DatabasePool

    init(path: String, dropTableFirst: Bool = false) throws {
        dbQueue = try DatabasePool(path: path, configuration: GRDB.Configuration())

        try dbQueue.write({ db in
            if dropTableFirst {
                try db.drop(table: Self.tableName)
            }

            try db.create(table: Self.tableName, ifNotExists: true) { table in
                table.column("id", .integer)
                table.column("uuid", .text).notNull().primaryKey().unique()
                table.column("host", .text).notNull().indexed()
                table.column("name", .text).notNull()
                table.column("password", .text).notNull()
            }
        })
    }

    private func id(for host: URL, and username: String) -> String {
        return PasswordManagerEntry(host: host, username: username).id
    }

    private func entries(for passwordsRecord: [PasswordsRecord]) -> [PasswordManagerEntry] {
        var entries: [PasswordManagerEntry] = []
        for passwordRecord in passwordsRecord {
            if let host = URL(string: passwordRecord.host) {
                entries.append(PasswordManagerEntry(host: host, username: passwordRecord.name))
            }
        }
        return entries
    }

    // PasswordStore
    func entries(for host: URL, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbQueue.read { db in
                let passwords = try PasswordsRecord
                    .filter(PasswordsRecord.Columns.host == host.minimizedHost)
                    .fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while fetching password entries for \(host): \(error)", category: .passwordsDB)
        }
    }

    func find(_ searchString: String, completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbQueue.read { db in
                let passwords = try PasswordsRecord
                    .filter(PasswordsRecord.Columns.host.like("%\(searchString)%"))
                    .fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch let error {
            Logger.shared.logError("Error while searching password for \(searchString): \(error)", category: .passwordsDB)
        }
    }

    func fetchAll(completion: @escaping ([PasswordManagerEntry]) -> Void) {
        do {
            try dbQueue.read { db in
                let passwords = try PasswordsRecord.fetchAll(db)
                completion(entries(for: passwords))
            }
        } catch {
            Logger.shared.logError("Error while fetching all passwords: \(error)", category: .passwordsDB)
        }
    }

    func password(host: URL, username: String, completion: @escaping (String?) -> Void) {
        do {
            try dbQueue.read { db in
                guard let passwordRecord = try PasswordsRecord.fetchOne(db, key: id(for: host, and: username)) else {
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

    func save(host: URL, username: String, password: String) {
        do {
            try dbQueue.write { db in
                guard let encryptedPassword = try? EncryptionManager.shared.encryptString(password) else {
                    Logger.shared.logError("Error while encrypting password for \(host) - \(username)", category: .encryption)
                    return
                }
                var passwordRecord = PasswordsRecord(id: nil, uuid: id(for: host, and: username), host: host.minimizedHost, name: username, password: encryptedPassword)
                try passwordRecord.insert(db)
            }
        } catch let error {
            Logger.shared.logError("Error while saving password for \(host): \(error)", category: .passwordsDB)
        }
    }

    func delete(host: URL, username: String) {
        _ = try? dbQueue.write { db in
            try PasswordsRecord.deleteOne(db, key: id(for: host, and: username))
        }
    }

    // Added only in the purpose of testing maybe will be added in the protocol if needed
    func deleteAll() {
        _ = try? dbQueue.write { db in
            try PasswordsRecord.deleteAll(db)
        }
    }
}
