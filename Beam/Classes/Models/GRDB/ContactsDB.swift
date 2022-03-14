//
//  ContactsDB.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 24/11/2021.
//

import Foundation
import GRDB
import BeamCore

enum ContactsDBError: Error {
    case errorFetchingContacts(errorMsg: String)
    case cantSaveContact(errorMsg: String)
    case cantDeleteContact(errorMsg: String)
}

struct ContactRecord: Decodable {
    internal static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.string

    var uuid: UUID = .null
    var noteId: UUID
    var emails: [Email]

    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

extension ContactRecord: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
        hasher.combine(noteId)
        hasher.combine(emails)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
        hasher.combine(deletedAt)
    }
}

extension ContactRecord: BeamObjectProtocol {
    static var beamObjectType: BeamObjectObjectType {
        BeamObjectObjectType.contact
    }

    var beamObjectId: UUID {
        get { uuid }
        set { uuid = newValue }
    }

    enum CodingKeys: String, CodingKey {
        case noteId
        case emails
        case createdAt
        case updatedAt
        case deletedAt
    }

    func copy() -> ContactRecord {
        ContactRecord(uuid: uuid,
                      noteId: noteId,
                      emails: emails,
                      createdAt: createdAt,
                      updatedAt: updatedAt,
                      deletedAt: deletedAt)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        noteId = try values.decode(UUID.self, forKey: .noteId)
        emails = try values.decode([Email].self, forKey: .emails)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        deletedAt = try values.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(noteId, forKey: .noteId)
        try container.encode(emails, forKey: .emails)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        if deletedAt != nil {
            try container.encode(deletedAt, forKey: .deletedAt)
        }
    }
}

extension ContactRecord: Equatable {
    static func == (lhs: ContactRecord, rhs: ContactRecord) -> Bool {
        lhs.uuid == rhs.uuid &&
        lhs.noteId == rhs.noteId &&
        lhs.emails == rhs.emails &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.deletedAt == rhs.deletedAt
    }
}

extension ContactRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case uuid, noteId, emails, createdAt, updatedAt, deletedAt, previousChecksum
    }
}

extension ContactRecord: FetchableRecord {
    init(row: Row) {
        uuid = row[Columns.uuid]
        noteId = row[Columns.noteId]
        if let data = row[Columns.emails] as? Data {
            let decodedEmails = try? BeamJSONDecoder().decode([Email].self, from: data)
            emails = decodedEmails ?? []
        } else {
            emails = []
        }
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
    }
}

extension ContactRecord: MutablePersistableRecord {
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.uuid] = uuid
        container[Columns.noteId] = noteId
        container[Columns.emails] = try? JSONEncoder().encode(emails)
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
    }
}

class ContactsDB {
    static let tableName = "contactRecord"
    var dbPool: DatabasePool

    init(path: String) throws {
        dbPool = try DatabasePool(path: path, configuration: GRDB.Configuration())

        var migrator = DatabaseMigrator()

        migrator.registerMigration("contactTableCreation") { db in
            try db.create(table: ContactsDB.tableName, ifNotExists: true) { table in
                table.column("uuid", .text).notNull().primaryKey().unique()
                table.column("noteId", .text).notNull().unique()
                table.column("emails", .blob).notNull()
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
            }
        }

        try migrator.migrate(dbPool)
    }

    func fetchWithId(_ id: UUID) throws -> ContactRecord? {
        try dbPool.read { db in
            try ContactRecord.filter(ContactRecord.Columns.uuid == id).fetchOne(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [ContactRecord] {
        try dbPool.read { db in
            try ContactRecord
                .filter(ids.contains(ContactRecord.Columns.uuid))
                .fetchAll(db)
        }
    }

    func allRecords(_ updatedSince: Date? = nil) throws -> [ContactRecord] {
        try dbPool.read { db in
            if let updatedSince = updatedSince {
                return try ContactRecord.filter(ContactRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try ContactRecord.fetchAll(db)
        }
    }

    func fetchAll() throws -> [ContactRecord] {
        do {
            return try dbPool.read { db in
                let contacts = try ContactRecord
                    .filter(ContactRecord.Columns.deletedAt == nil)
                    .fetchAll(db)
                return contacts
            }
        } catch {
            throw ContactsDBError.errorFetchingContacts(errorMsg: error.localizedDescription)
        }
    }

    func contact(for noteId: UUID) throws -> ContactRecord? {
        do {
            return try dbPool.read { db in
                return try ContactRecord
                    .filter(ContactRecord.Columns.noteId == noteId && ContactRecord.Columns.deletedAt == nil)
                    .fetchOne(db)
            }
        } catch let error {
            throw ContactsDBError.errorFetchingContacts(errorMsg: error.localizedDescription)
        }
    }

    func save(_ emails: [Email], to noteId: UUID) throws -> ContactRecord {
        do {
            return try dbPool.write { db in
                var contactRecord = ContactRecord(uuid: UUID(),
                                                  noteId: noteId,
                                                  emails: emails,
                                                  createdAt: BeamDate.now,
                                                  updatedAt: BeamDate.now,
                                                  deletedAt: nil)
                try contactRecord.insert(db)
                return contactRecord
            }
        } catch let error {
            throw ContactsDBError.cantSaveContact(errorMsg: error.localizedDescription)
        }
    }

    func save(contacts: [ContactRecord]) throws {
        try dbPool.write { db in
            for contact in contacts {
                var contact = contact.copy()
                try contact.insert(db)
            }
        }
    }

    func update(record: ContactRecord, with emails: [Email]) throws -> ContactRecord {
        do {
            return try dbPool.write { db in
                var updatedRecord = record
                updatedRecord.emails = emails
                updatedRecord.updatedAt = BeamDate.now
                try updatedRecord.save(db)
                return updatedRecord
            }
        } catch let error {
            throw ContactsDBError.cantSaveContact(errorMsg: error.localizedDescription)
        }
    }

    func markDeleted(noteId: UUID) throws -> ContactRecord {
        do {
            return try dbPool.write { db in
                try ContactRecord
                    .filter(ContactRecord.Columns.deletedAt == nil && ContactRecord.Columns.noteId == noteId)
                    .updateAll(db, ContactRecord.Columns.deletedAt.set(to: BeamDate.now))

                guard let contact = try ContactRecord
                        .filter(ContactRecord.Columns.deletedAt == BeamDate.now && ContactRecord.Columns.noteId == noteId)
                        .fetchOne(db) else {
                            throw ContactsDBError.cantDeleteContact(errorMsg: "Contact not found!")
                        }
                return contact
            }
        } catch let error {
            throw ContactsDBError.cantDeleteContact(errorMsg: error.localizedDescription)
        }
    }

    func markAllDeleted() throws -> [ContactRecord] {
            do {
                return try dbPool.write { db in
                    try ContactRecord
                        .filter(Column("deletedAt") == nil)
                        .updateAll(db, ContactRecord.Columns.deletedAt.set(to: BeamDate.now))

                    let contacts = try ContactRecord
                        .filter(ContactRecord.Columns.deletedAt == BeamDate.now)
                        .fetchAll(db)
                    return contacts
                }
            } catch let error {
                throw ContactsDBError.cantDeleteContact(errorMsg: error.localizedDescription)
            }
    }

    @discardableResult
    func delete(noteId: Int) throws -> ContactRecord? {
        do {
            return try dbPool.write { db in
                let contact = try ContactRecord
                    .filter(ContactRecord.Columns.noteId == noteId)
                    .fetchOne(db)
                try contact?.delete(db)
                return contact
            }
        } catch {
            throw ContactsDBError.cantDeleteContact(errorMsg: error.localizedDescription)
        }
    }

    @discardableResult
    func deleteAll() throws -> [ContactRecord] {
        do {
            return try dbPool.write { db in
                let contacts = try ContactRecord.fetchAll(db)
                try ContactRecord.deleteAll(db)
                return contacts
            }
        } catch {
            throw ContactsDBError.cantDeleteContact(errorMsg: error.localizedDescription)
        }
    }
}
