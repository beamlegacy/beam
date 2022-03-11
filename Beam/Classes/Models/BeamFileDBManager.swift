//
//  BeamFileDBManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/05/2021.
//
// swiftlint:disable file_length

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
}

// SQL generation
extension BeamFileRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case name, uid, data, type, createdAt, updatedAt, deletedAt, previousChecksum
    }
    static let tableName = "beamFileRecord"
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
    }
}

extension BeamFileRecord: BeamObjectProtocol {
    static var beamObjectType = BeamObjectObjectType.file

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
        BeamFileRecord(name: name, uid: uid, data: data, type: type, size: size, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

/// References from notes to files:
struct BeamFileRefRecord: Equatable, Hashable {
    var noteId: UUID
    var elementId: UUID
    var fileId: UUID
}

// SQL generation
extension BeamFileRefRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case noteId, elementId, fileId
    }
    static let tableName = "beamFileRefRecord"
}

// Fetching methods
extension BeamFileRefRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        noteId = row[Columns.noteId]
        elementId = row[Columns.elementId]
        fileId = row[Columns.fileId]
    }
}

// Persistence methods
extension BeamFileRefRecord: MutablePersistableRecord {
    /// The values persisted in the database
    static let persistenceConflictPolicy = PersistenceConflictPolicy(
            insert: .replace,
            update: .replace)

    func encode(to container: inout PersistenceContainer) {
        container[Columns.noteId] = noteId
        container[Columns.elementId] = elementId
        container[Columns.fileId] = fileId
    }
}

protocol BeamFileStorage {
    func fetch(uid: UUID) throws -> BeamFileRecord?
    func insert(name: String, data: Data, type: String?) throws -> UUID
    func remove(uid: UUID) throws
    func clear() throws

    func addReference(fromNote: UUID, element: UUID, to: UUID) throws
    func removeReference(fromNote: UUID, element: UUID?, to: UUID?) throws
    func purgeUnlinkedFiles() throws
    func purgeUndo() throws
    func clearFileReferences() throws
    func referenceCount(fileId: UUID) throws -> Int
    func referencesFor(fileId: UUID) throws -> [BeamNoteReference]
}

class BeamFileDBManager: BeamFileStorage {
    static let shared: BeamFileDBManager = {
        do {
            return try BeamFileDBManager(path: BeamData.fileDBPath)
        } catch {
            Logger.shared.logError("Unable to create shared BeamFileDBManager: \(error)", category: .fileDB)
            let alert = NSAlert(error: error)
            alert.runModal()
            exit(0)
        }
    }()

    var dbPool: DatabaseWriter

    //swiftlint:disable:next function_body_length
    init(path: String) throws {
        let configuration = GRDB.Configuration()

        if path == ":memory:" {
            // we use memory for tests, but DatabasePool doesn't work in memory apparently
            dbPool = try DatabaseQueue(path: path, configuration: configuration)
        } else {
            dbPool = try DatabasePool(path: path, configuration: configuration)
        }

        var migrator = DatabaseMigrator()

        migrator.registerMigration("migrateToUUID2") { db in
            let rows = try? Row.fetchAll(db, sql: "SELECT id, name, uid, data, type FROM BeamFileRecord")

            if try db.tableExists(BeamFileRecord.tableName) {
                try db.drop(table: BeamFileRecord.tableName)
            }
            try db.create(table: BeamFileRecord.tableName, ifNotExists: true) { table in
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
                        deletedAt: nil)
                    try fileRecord.insert(db)
                }
            }
        }

        migrator.registerMigration("addUpdatedAtIndex") { db in
            try db.create(index: "byUpdatedAt", on: BeamFileRecord.tableName, columns: ["updatedAt"], unique: false)
        }

        migrator.registerMigration("addReferenceTable") { db in
            try db.create(table: BeamFileRefRecord.tableName, ifNotExists: true) { table in
                table.column("noteId", .blob).notNull().indexed()
                table.column("elementId", .blob).notNull().indexed()
                table.column("fileId", .blob).notNull().indexed()
            }

            DispatchQueue.main.async {
                do {
                    try AppDelegate.main.data.reindexFileReferences()
                } catch {
                    Logger.shared.logError("Error while reindexing all file references: \(error)", category: .fileDB)
                }
            }
        }

        try migrator.migrate(dbPool)

        try purgeUndo()
        try purgeUnlinkedFiles()
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

    func insert(name: String, data: Data, type: String? = nil) throws -> UUID {
        let uid = UUID.v5(name: data.SHA256, namespace: .url)
        let mimeType = type ?? Swime.mimeType(data: data)?.mime ?? "application/octet-stream"
        let file = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
        try dbPool.write { db in
            var f = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
            try f.insert(db)
        }
        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            try self.saveOnNetwork(file)
        }
        return uid
    }

    func insert(files: [BeamFileRecord]) throws {
        do {
            try dbPool.write { db in
                for file in files {
                    var fileToInsert = file
                    try fileToInsert.insert(db)
                }
            }

            if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                try self.saveAllOnNetwork(files)
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

    func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try self.clear()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                try self.deleteAllFromBeamObjectAPI { result in
                    networkCompletion?(result)
                }
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .fileDB)
        }
        networkCompletion?(.success(false))
    }

    func allRecords(_ updatedSince: Date? = nil) throws -> [BeamFileRecord] {
        try dbPool.read { db in
            if let updatedSince = updatedSince {
                return try BeamFileRecord.filter(PasswordRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try BeamFileRecord.fetchAll(db)
        }
    }

    func fileCount() throws -> Int {
        try dbPool.read { db in
            return try BeamFileRecord.fetchCount(db)
        }
    }

    func addReference(fromNote: UUID, element: UUID, to: UUID) throws {
        try dbPool.write { db in
            var ref = BeamFileRefRecord(noteId: fromNote, elementId: element, fileId: to)
            try ref.insert(db)
        }
    }

    func removeReference(fromNote: UUID, element: UUID?, to: UUID? = nil) throws {
        try dbPool.write { db in
            defer {
                do {
                    if try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == to).fetchCount(db) == 0 {
                        if var file = try BeamFileRecord.filter(BeamFileRecord.Columns.uid == to).filter(BeamFileRecord.Columns.deletedAt == nil).fetchOne(db) {
                            file.deletedAt = BeamDate.now
                            try file.save(db)
                            if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                                try self.saveOnNetwork(file)
                            }
                        }
                    }
                } catch {
                    Logger.shared.logError("Unable to delete unreferenced file \(String(describing: to))", category: .fileDB)
                }
            }
            guard let to = to else {
                if let element = element {
                    try BeamFileRefRecord
                        .filter(BeamFileRefRecord.Columns.noteId == fromNote)
                        .filter(BeamFileRefRecord.Columns.elementId == element)
                        .deleteAll(db)
                } else {
                    try BeamFileRefRecord
                        .filter(BeamFileRefRecord.Columns.noteId == fromNote)
                        .deleteAll(db)
                }
                return
            }
            if let element = element {
                try BeamFileRefRecord
                    .filter(BeamFileRefRecord.Columns.noteId == fromNote)
                    .filter(BeamFileRefRecord.Columns.elementId == element)
                    .filter(BeamFileRefRecord.Columns.fileId == to)
                    .deleteAll(db)
            } else {
                try BeamFileRefRecord
                    .filter(BeamFileRefRecord.Columns.noteId == fromNote)
                    .filter(BeamFileRefRecord.Columns.fileId == to)
                    .deleteAll(db)
            }
        }
    }

    func purgeUnlinkedFiles() throws {
        _ = try dbPool.write { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT uid FROM \(BeamFileRecord.tableName)")
            while let row = try rows.next() {
                let fileId: UUID = row[BeamFileRecord.Columns.uid]
                if try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchCount(db) == 0 {
                    do {
                        guard var file = try BeamFileRecord.filter(BeamFileRecord.Columns.uid == fileId).filter(BeamFileRecord.Columns.deletedAt == nil).fetchOne(db) else { continue }
                        file.deletedAt = BeamDate.now
                        try file.save(db)
                        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                            try self.saveOnNetwork(file)
                        }

                    } catch {
                        Logger.shared.logError("Unable to delete unreferenced file \(fileId)", category: .fileDB)
                    }
                }
            }
        }
    }

    func purgeUndo() throws {
        try removeReference(fromNote: UUID.null, element: nil)
    }

    func referenceCount(fileId: UUID) throws -> Int {
        try dbPool.read { db in
            try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchCount(db)
        }
    }

    func referencesFor(fileId: UUID) throws -> [BeamNoteReference] {
        try dbPool.read { db in
            (try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchAll(db)).map { record in
                BeamNoteReference(noteID: record.noteId, elementID: record.elementId)
            }
        }
    }

    func clearFileReferences() throws {
        _ = try dbPool.write { db in
            try BeamFileRefRecord.deleteAll(db)
        }
    }

    func refresh(_ file: BeamFileRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        try self.refreshFromBeamObjectAPI(file, true) { result in
            switch result {
            case .success(let remoteFile):
                if let remoteFile = remoteFile {
                    do {
                        try self.insert(files: [remoteFile])
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
    static var uploadType: BeamObjectRequestUploadType {
        .directUpload
    }
    internal static var backgroundQueue: DispatchQueue = DispatchQueue(label: "BeamFileDBManager BeamObjectManager backgroundQueue", qos: .userInitiated)

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ files: [BeamFileRecord]) throws {
        try insert(files: files)
    }

    func allObjects(updatedSince: Date?) throws -> [BeamFileRecord] {
        try allRecords(updatedSince)
    }

    func saveAllOnNetwork(_ files: [BeamFileRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                // swiftlint:disable:next date_init
                let localTimer = Date()
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
                // swiftlint:disable:next date_init
                let localTimer = Date()
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

    func manageConflict(_ object: BeamFileRecord,
                        _ remoteObject: BeamFileRecord) throws -> BeamFileRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [BeamFileRecord]) throws {
        try insert(files: objects)
    }

}

extension BeamFileRecord: Identifiable {
    public var id: UUID { uid }
}
