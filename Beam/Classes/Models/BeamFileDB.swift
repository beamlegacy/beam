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
import Swime

// The new version of the BeamFileRecord (where uid is an UUID)
struct BeamFileRecord: Equatable, Hashable {
    var name: String
    var uid: UUID
    var data: Data
    var type: String
    var size: Int

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
        case name, uid, data, type, createdAt, updatedAt, deletedAt, previousChecksum
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
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
        previousChecksum = row[Columns.previousChecksum]
        size = data.count
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
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
        container[Columns.previousChecksum] = previousChecksum
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
        case size
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        uid = try (try? container.decode(UUID.self, forKey: .uid)) ?? UUID.v5(name: (try container.decode(String.self, forKey: .uid)), namespace: .url)
        type = try container.decode(String.self, forKey: .type)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)

        data = try container.decode(Data.self, forKey: .data)
        size = data.count
    }

    func copy() throws -> BeamFileRecord {
        BeamFileRecord(name: name, uid: uid, data: data, type: type, size: size, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, previousChecksum: previousChecksum)
    }
}

protocol BeamFileStorage {
    func fetch(uid: UUID) throws -> BeamFileRecord?
    func insert(name: String, data: Data, type: String?) throws -> UUID
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
        migrator.registerMigration("saveOldData2") { db in
            rows = try? Row.fetchAll(db, sql: "SELECT id, name, uid, data, type FROM BeamFileRecord")
        }

        migrator.registerMigration("migrateToUUID2") { db in
            if try db.tableExists("BeamFileRecord") {
                try db.drop(table: "BeamFileRecord")
            }
            try db.create(table: BeamFileDB.tableName, ifNotExists: true) { table in
                table.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                table.column("uid", .text).notNull().primaryKey().unique()
                table.column("data", .blob)
                table.column("type", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }

            if let storedFiles = rows {
                for file in storedFiles {
                    let data = file["data"] as Data
                    let uid = UUID.v5(name: data.SHA256, namespace: .url)
                    var fileRecord = BeamFileRecord(
                        name: file["name"],
                        uid: uid,
                        data: file["data"],
                        type: file["type"],
                        size: data.count,
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
        try dbPool.read { db in
            try? BeamFileRecord.fetchOne(db, key: uid)
        }
    }

    func fetchRandom() throws -> BeamFileRecord? {
        try dbPool.read { db in
            try? BeamFileRecord.fetchOne(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [BeamFileRecord] {
        try dbPool.read { db in
            try BeamFileRecord
                .filter(ids.contains(BeamFileRecord.Columns.uid))
                .fetchAll(db)
        }
    }

    func fetchWithBeamObjectId(id: UUID) throws -> BeamFileRecord? {
        try dbPool.read({ db in
            try? BeamFileRecord.filter(Column("uid") == id).fetchOne(db)
        })
    }

    func insert(name: String, data: Data, type: String?) throws -> UUID {
        let uid = UUID.v5(name: data.SHA256, namespace: .url)
        let mimeType = type ?? Swime.mimeType(data: data)?.mime ?? "application/octet-stream"

        return try dbPool.write { db -> UUID in
            var f = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
            try f.insert(db)
            return uid
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

    func allRecords(_ updatedSince: Date? = nil) throws -> [BeamFileRecord] {
        try dbPool.read { db in
            if let updatedSince = updatedSince {
                return try BeamFileRecord.filter(PasswordRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try BeamFileRecord.fetchAll(db)
        }
    }
}

class BeamFileDBManager: BeamFileStorage {
    static let shared = BeamFileDBManager()
    //swiftlint:disable:next force_try
    static var fileDB: BeamFileDB = try! BeamFileDB(path: BeamData.fileDBPath)

    func insert(name: String, data: Data, type: String? = nil) throws -> UUID {
        let uid = UUID.v5(name: data.SHA256, namespace: .url)
        let mimeType = type ?? Swime.mimeType(data: data)?.mime ?? "application/octet-stream"
        let file = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
        try Self.fileDB.insert(files: [file])
        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            try self.saveOnNetwork(file)
        }
        return uid
    }

    func fetch(uid: UUID) throws -> BeamFileRecord? {
        try Self.fileDB.fetch(uid: uid)
    }

    func remove(uid: UUID) throws {
        try Self.fileDB.remove(uid: uid)
    }

    func clear() throws {
        try Self.fileDB.clear()
    }

    func refresh(_ file: BeamFileRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try self.refreshFromBeamObjectAPI(file, true) { result in
            switch result {
            case .success(let remoteFile):
                if var remoteFile = remoteFile {
                    do {
                        remoteFile.previousChecksum = remoteFile.checksum
                        try Self.fileDB.insert(files: [remoteFile])
                    } catch {
                        networkCompletion?(.failure(error))
                    }
                }
                networkCompletion?(.success(true))
            case .failure(let error):
                networkCompletion?(.failure(error))
            }
        }
    }
}

enum BeamFileDBManagerError: Error, Equatable {
    case localFileNotFound
}

extension BeamFileDBManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue: DispatchQueue = DispatchQueue(label: "BeamFileDBManager BeamObjectManager backgroundQueue", qos: .userInitiated)

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ files: [BeamFileRecord]) throws {
        try Self.fileDB.insert(files: files)
    }

    func allObjects(updatedSince: Date?) throws -> [BeamFileRecord] {
        try Self.fileDB.allRecords(updatedSince)
    }

    func checksumsForIds(_ ids: [UUID]) throws -> [UUID: String] {
        let values: [(UUID, String)] = try Self.fileDB.fetchWithIds(ids).compactMap {
            guard let previousChecksum = $0.previousChecksum else { return nil }
            return ($0.beamObjectId, previousChecksum)
        }

        return Dictionary(uniqueKeysWithValues: values)
    }

    func saveAllOnNetwork(_ files: [BeamFileRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                let localTimer = BeamDate.now
                try self?.saveOnBeamObjectsAPI(files) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved \(files.count) files on the BeamObject API",
                                               category: .fileNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the files on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .fileNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    private func saveOnNetwork(_ file: BeamFileRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                let localTimer = BeamDate.now
                try self?.saveOnBeamObjectAPI(file) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved file \(file.name) on the BeamObject API",
                                               category: .fileNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the file on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .fileNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    func persistChecksum(_ objects: [BeamFileRecord]) throws {
        Logger.shared.logDebug("Saved \(objects.count) \(Self.BeamObjectType) checksums",
                               category: .fileNetwork)

        var files: [BeamFileRecord] = []
        for updateObject in objects {
            // TODO: make faster with a `fetchWithIds(ids: [UUID])`
            guard var file = try? Self.fileDB.fetchWithBeamObjectId(id: updateObject.beamObjectId) else {
                throw BeamFileDBManagerError.localFileNotFound
            }

            file.previousChecksum = updateObject.previousChecksum
            files.append(file)
        }
        try Self.fileDB.insert(files: files)
    }

    func manageConflict(_ object: BeamFileRecord,
                        _ remoteObject: BeamFileRecord) throws -> BeamFileRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [BeamFileRecord]) throws {
        try Self.fileDB.insert(files: objects)
    }

}

extension BeamFileRecord: Identifiable {
    public var id: UUID { uid }
}
