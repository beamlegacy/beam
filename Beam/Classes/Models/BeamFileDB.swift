//
//  BeamFileDB.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/05/2021.
//

import Foundation
import BeamCore
import GRDB

struct BeamFileRecord {
    var id: Int64?
    var name: String
    var uid: String
    var data: Data
    var type: String
}

// SQL generation
extension BeamFileRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case id, name, uid, data, type
    }
}

// Fetching methods
extension BeamFileRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        uid = row[Columns.uid]
        data = row[Columns.data]
        type = row[Columns.type]
    }
}

// Persistence methods
extension BeamFileRecord: MutablePersistableRecord {
    /// The values persisted in the database
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.uid] = uid
        container[Columns.data] = data
        container[Columns.type] = type
    }

    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

class BeamFileDB {
    var dbQueue: DatabasePool
    init(path: String) throws {
        let configuration = GRDB.Configuration()

        dbQueue = try DatabasePool(path: path, configuration: configuration)
        try dbQueue.write { db in
            try db.create(table: "BeamFileRecord", ifNotExists: true) { t in
                t.column("id", .integer)
                t.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                t.column("uid", .text).notNull().collate(.caseInsensitiveCompare).primaryKey()
                t.column("data", .blob)
                t.column("type", .text)
            }
        }
    }

    func fetch(uid: String) throws -> BeamFileRecord? {
        try dbQueue.read({ db in
            try? BeamFileRecord.fetchOne(db, key: uid)
        })
    }

    func insert(name: String, uid: String, data: Data, type: String) throws {
        do {
            try dbQueue.write { db in
                var f = BeamFileRecord(id: nil, name: name, uid: uid, data: data, type: type)
                try f.insert(db)
            }
        } catch let error {
            Logger.shared.logError("Error while inserting file \(name) - \(uid): \(error)", category: .fileDB)
            throw error
        }
    }

    func remove(uid: String) throws {
        _ = try dbQueue.write { db in
            try BeamFileRecord.deleteOne(db, key: ["uid": uid])
        }
    }

    func clear() throws {
        _ = try dbQueue.write { db in
            try BeamFileRecord.deleteAll(db)
        }
    }

}
