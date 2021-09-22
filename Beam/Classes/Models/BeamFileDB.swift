//
//  BeamFileDB.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/05/2021.
//

import Foundation
import BeamCore
import GRDB
import UUIDKit

struct BeamFileRecordOld {
    var name: String
    var uid: String
    var data: Data
    var type: String

    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?
    var previousChecksum: String?
    var checksum: String?
}

extension BeamFileRecordOld: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case name, uid, data, type
    }
}

// Persistence methods
extension BeamFileRecordOld: MutablePersistableRecord {
    /// The values persisted in the database
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
        insert: .replace,
        update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.name] = name
        container[Columns.uid] = uid
        container[Columns.data] = data
        container[Columns.type] = type
    }
}

// The new version of the BeamFileRecord (where uid is an UUID)
struct BeamFileRecord {
    var name: String
    var uid: UUID
    var data: Data
    var type: String

    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?
    var previousChecksum: String?
    var checksum: String?
}

// SQL generation
extension BeamFileRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case name, uid, data, type
    }
}

// Fetching methods
extension BeamFileRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
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
        container[Columns.name] = name
        container[Columns.uid] = uid
        container[Columns.data] = data
        container[Columns.type] = type
    }
}

extension BeamFileRecord: BeamObjectProtocol {
    static var beamObjectTypeName: String = "file"

    var beamObjectId: UUID {
        get {
            uid
        }
        set {
            uid = newValue
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case uid
        case type

        case createdAt
        case updatedAt
        case deletedAt

        case data
    }

    func copy() throws -> BeamFileRecord {
        BeamFileRecord(name: name, uid: uid, data: data, type: type, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, previousChecksum: previousChecksum, checksum: checksum)
    }
}

protocol BeamFileStorage {
    func fetch(uid: UUID) throws -> BeamFileRecord?
    func insert(name: String, uid: UUID, data: Data, type: String) throws
    func remove(uid: UUID) throws
    func clear() throws
}

class BeamFileDB: BeamFileStorage {
    static let tableName = "beamFileRecord"
    var dbPool: DatabasePool

    //swiftlint:disable:next function_body_length
    init(path: String) throws {
        let configuration = GRDB.Configuration()

        dbPool = try DatabasePool(path: path, configuration: configuration)

        var migrator = DatabaseMigrator()

        var rows: [Row]?
        migrator.registerMigration("saveOldData") { db in
            rows = try? Row.fetchAll(db, sql: "SELECT id, name, uid, data, type FROM BeamFileRecord")
        }

        migrator.registerMigration("beamFileTableCreation") { db in
            try db.create(table: BeamFileDB.tableName, ifNotExists: true) { table in
                table.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                table.column("uid", .text).notNull().collate(.caseInsensitiveCompare).primaryKey()
                table.column("data", .blob)
                table.column("type", .text)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }
        }

        migrator.registerMigration("migrateOldData") { db in
            if let storedFiles = rows {
                for file in storedFiles {
                    var fileRecord = BeamFileRecordOld(
                        name: file["name"],
                        uid: file["uid"],
                        data: file["data"],
                        type: file["type"],
                        createdAt: BeamDate.now,
                        updatedAt: BeamDate.now,
                        deletedAt: nil,
                        previousChecksum: nil)
                    try fileRecord.insert(db)
                }
            }
        }

        migrator.registerMigration("migrateToUUID") { db in
            if let storedFiles = rows {
                for file in storedFiles {
                    let id = file["uid"] as String
                    let uuid = UUID(uuidString: id) ?? UUID.v5(name: id, namespace: .url)
                    var fileRecord = BeamFileRecord(
                        name: file["name"],
                        uid: uuid,
                        data: file["data"],
                        type: file["type"],
                        createdAt: BeamDate.now,
                        updatedAt: BeamDate.now,
                        deletedAt: nil,
                        previousChecksum: nil)
                    try fileRecord.insert(db)
                }
            }
        }

        try migrator.migrate(dbPool)
    }

    func fetch(uid: UUID) throws -> BeamFileRecord? {
        try dbPool.read({ db in
            try? BeamFileRecord.fetchOne(db, key: uid)
        })
    }

    func fetchWithBeamObjectId(id: UUID) throws -> BeamFileRecord? {
        try dbPool.read({ db in
            try? BeamFileRecord.filter(Column("uid") == id).fetchOne(db)
        })
    }

    func insert(name: String, uid: UUID, data: Data, type: String) throws {
        do {
            try dbPool.write { db in
                var f = BeamFileRecord(name: name, uid: uid, data: data, type: type)
                try f.insert(db)
            }
        } catch let error {
            Logger.shared.logError("Error while inserting file \(name) - \(uid): \(error)", category: .fileDB)
            throw error
        }
    }

    func insert(files: [BeamFileRecord]) throws {
        do {
            try dbPool.write { db in
                for file in files {
                    var fileToInsert = file
                    try fileToInsert.insert(db)
                }
            }
        } catch let error {
            Logger.shared.logError("Error while inserting files \(files): \(error)", category: .fileDB)
            throw error
        }
    }

    func remove(uid: UUID) throws {
        _ = try dbPool.write { db in
            try BeamFileRecord.deleteOne(db, key: ["uid": uid])
        }
    }

    func clear() throws {
        _ = try dbPool.write { db in
            try BeamFileRecord.deleteAll(db)
        }
    }

    func allRecords() throws -> [BeamFileRecord] {
        try dbPool.read({ db in
            try BeamFileRecord.fetchAll(db)
        })
    }
}

class BeamFileDBManager: BeamFileStorage {
    static let shared = BeamFileDBManager()
    var fileDB: BeamFileDB

    func insert(name: String, uid: UUID, data: Data, type: String) {
        do {
            let file = BeamFileRecord(name: name, uid: uid, data: data, type: type)
            try fileDB.insert(files: [file])
            try self.saveOnNetwork(file)
        } catch {
            Logger.shared.logError("Error inserting a new file in DB: \(error)", category: .fileDB)
        }
    }

    func fetch(uid: UUID) throws -> BeamFileRecord? {
        try fileDB.fetch(uid: uid)
    }

    func remove(uid: UUID) throws {
        try fileDB.remove(uid: uid)
    }

    func clear() throws {
        try fileDB.clear()
    }

    init() {
        do {
            fileDB = try BeamFileDB(path: BeamData.fileDBPath)
        } catch let error {
            Logger.shared.logError("Error while creating the File Database [\(error)]", category: .fileDB)
            fatalError()
        }
    }
}

enum BeamFileDBManagerError: Error, Equatable {
    case localFileNotFound
}

extension BeamFileDBManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ files: [BeamFileRecord]) throws {
        Logger.shared.logDebug("Received \(files.count) files: updating",
                               category: .fileNetwork)

        try fileDB.insert(files: files)
    }

    func allObjects() throws -> [BeamFileRecord] {
        try fileDB.allRecords()
    }

    func saveAllOnNetwork(_ files: [BeamFileRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try self.saveOnBeamObjectsAPI(files) { result in
            switch result {
            case .success:
                Logger.shared.logDebug("Saved files on the BeamObject API",
                                       category: .fileNetwork)
                networkCompletion?(.success(true))
            case .failure(let error):
                Logger.shared.logDebug("Error when saving the files on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ file: BeamFileRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try self.saveOnBeamObjectAPI(file) { result in
            switch result {
            case .success:
                Logger.shared.logDebug("Saved file on the BeamObject API",
                                       category: .fileNetwork)
                networkCompletion?(.success(true))
            case .failure(let error):
                Logger.shared.logDebug("Error when saving the file on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    func persistChecksum(_ objects: [BeamFileRecord]) throws {
        Logger.shared.logDebug("Saved \(objects.count) files on the BeamObject API",
                               category: .fileNetwork)

        var files: [BeamFileRecord] = []
        for updateObject in objects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var file = try? fileDB.fetchWithBeamObjectId(id: updateObject.beamObjectId) else {
                throw BeamFileDBManagerError.localFileNotFound
            }

            file.previousChecksum = updateObject.previousChecksum
            files.append(file)
        }
        try fileDB.insert(files: files)
    }

    func manageConflict(_ object: BeamFileRecord,
                        _ remoteObject: BeamFileRecord) throws -> BeamFileRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [BeamFileRecord]) throws {
        try fileDB.insert(files: objects)
    }

}
