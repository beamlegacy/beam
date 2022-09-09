//
//  BeamFileDBManager.swift
//  Beam
//
//  Created by Sebastien Metrot on 06/05/2021.
//

import Foundation
import BeamCore
import GRDB
import UUIDKit
import Swime
import Combine

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

class BeamFileDBManager: GRDBHandler, BeamFileStorage, BeamManager, LegacyAutoImportDisabler {
    let objectManager: BeamObjectManager
    var changedObjects: [UUID: BeamFileRecord] = [:]
    let objectQueue = BeamObjectQueue<BeamFileRecord>()
    static var id = UUID()
    static var name = "BeamFileDBManager"

    static let fileSaved = PassthroughSubject<BeamFileRecord, Never>()
    static let fileDeleted = PassthroughSubject<UUID, Never>()

    weak var owner: BeamManagerOwner?

    override var tableNames: [String] { [BeamFileRecord.tableName, BeamFileRefRecord.tableName] }

    var grdbStore: GRDBStore

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.owner = holder
        self.objectManager = objectManager
        self.grdbStore = store
        try super.init(store: store)


        // Do not register now, as every new instance will override the current instance owned
        // by BeamObjectManager.
        // Not that we should do better and avoid having a global BeamObjectManager
        // and multiple accounts

//         registerOnBeamObjectManager(objectManager)

    }

    override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("initialCreation") { db in
            try db.create(table: BeamFileRecord.tableName, ifNotExists: true) { table in
                table.column("name", .text).notNull().collate(.localizedCaseInsensitiveCompare)
                table.column("uid", .text).notNull().primaryKey().unique()
                table.column("data", .blob)
                table.column("type", .text).collate(.localizedCaseInsensitiveCompare)
                table.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                table.column("deletedAt", .datetime)
                table.column("previousChecksum", .text)
            }

            try db.create(table: BeamFileRefRecord.tableName, ifNotExists: true) { table in
                table.column("noteId", .blob).notNull().indexed()
                table.column("elementId", .blob).notNull().indexed()
                table.column("fileId", .blob).notNull().indexed()
            }
        }
    }

    func postMigrationSetup() throws {
        try purgeUndo()
        try purgeUnlinkedFiles()
    }

    func fetch(uid: UUID) throws -> BeamFileRecord? {
        try read { db in
            try? BeamFileRecord.fetchOne(db, key: uid)
        }
    }

    func fetchRandom() throws -> BeamFileRecord? {
        try read { db in
            try? BeamFileRecord.fetchOne(db)
        }
    }

    func fetchWithIds(_ ids: [UUID]) throws -> [BeamFileRecord] {
        try read { db in
            try BeamFileRecord
                .filter(ids.contains(BeamFileRecord.Columns.uid))
                .fetchAll(db)
        }
    }

    func fetchWithBeamObjectId(id: UUID) throws -> BeamFileRecord? {
        try read({ db in
            try? BeamFileRecord.filter(Column("uid") == id).fetchOne(db)
        })
    }

    public static func uuidFor(data: Data) -> UUID {
        let uid = UUID.v5(name: data.SHA256, namespace: .url)
        return uid
    }

    func insert(name: String, data: Data, type: String? = nil) throws -> UUID {
        let uid = Self.uuidFor(data: data)
        let mimeType = type ?? Swime.mimeType(data: data)?.mime ?? "application/octet-stream"
        let file = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
        try write { db in
            var f = BeamFileRecord(name: name, uid: uid, data: data, type: mimeType, size: data.count)
            try f.insert(db)
            Self.fileSaved.send(f)
        }
        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            try self.saveOnNetwork(file)
        }
        return uid
    }

    func insert(files: [BeamFileRecord]) throws {
        do {
            try write { db in
                for file in files {
                    var fileToInsert = file
                    try fileToInsert.insert(db)
                    Self.fileSaved.send(fileToInsert)
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
        _ = try write { db in
            try BeamFileRecord.deleteOne(db, key: ["uid": uid])
            Self.fileDeleted.send(uid)
        }
    }

    override func clear() throws {
        _ = try write { db in
            try BeamFileRecord.deleteAll(db)
        }
    }

    func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try self.clear()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                Task {
                    do {
                        try await self.deleteAllFromBeamObjectAPI()
                        networkCompletion?(.success(true))
                    } catch {
                        Logger.shared.logError("Error while deleting all contacts: \(error)", category: .contactsDB)
                        networkCompletion?(.success(false))
                    }
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
        try read { db in
            if let updatedSince = updatedSince {
                return try BeamFileRecord.filter(BeamFileRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try BeamFileRecord.fetchAll(db)
        }
    }

    func fileCount() throws -> Int {
        try read { db in
            return try BeamFileRecord.fetchCount(db)
        }
    }

    func addReference(fromNote: UUID, element: UUID, to: UUID) throws {
        try write { db in
            var ref = BeamFileRefRecord(noteId: fromNote, elementId: element, fileId: to)
            try ref.insert(db)
        }
    }

    func removeReference(fromNote: UUID, element: UUID?, to: UUID? = nil) throws {
        try write { db in
            defer {
                do {
                    if try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == to).fetchCount(db) == 0 {
                        if var file = try BeamFileRecord.filter(BeamFileRecord.Columns.uid == to).filter(BeamFileRecord.Columns.deletedAt == nil).fetchOne(db) {
                            file.deletedAt = BeamDate.now
                            file.updatedAt = BeamDate.now
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
        _ = try write { db in
            let rows = try Row.fetchCursor(db, sql: "SELECT uid, deletedAt FROM \(BeamFileRecord.tableName)")
            while let row = try rows.next() {
                let fileId: UUID = row[BeamFileRecord.Columns.uid]
                let deletedAt: Date? = row[BeamFileRecord.Columns.deletedAt]
                if try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchCount(db) == 0 {
                    do {
                        guard var file = try BeamFileRecord.filter(BeamFileRecord.Columns.uid == fileId).filter(BeamFileRecord.Columns.deletedAt == nil).fetchOne(db) else { continue }
                        file.deletedAt = BeamDate.now
                        file.updatedAt = BeamDate.now
                        try file.save(db)
                        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                            try self.saveOnNetwork(file)
                        }

                    } catch {
                        Logger.shared.logError("Unable to delete unreferenced file \(fileId)", category: .fileDB)
                    }
                } else if deletedAt != nil {
                    do {
                        guard var file = try BeamFileRecord.filter(BeamFileRecord.Columns.uid == fileId).fetchOne(db) else { continue }
                        file.deletedAt = nil
                        file.updatedAt = BeamDate.now
                        try file.save(db)
                        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
                            try self.saveOnNetwork(file)
                        }
                    } catch {
                        Logger.shared.logError("Unable to undelete file \(fileId)", category: .fileDB)
                    }
                }
            }
        }
    }

    func purgeUndo() throws {
        try removeReference(fromNote: UUID.null, element: nil)
    }

    func referenceCount(fileId: UUID) throws -> Int {
        try read { db in
            try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchCount(db)
        }
    }

    func referencesFor(fileId: UUID) throws -> [BeamNoteReference] {
        try read { db in
            (try BeamFileRefRecord.filter(BeamFileRefRecord.Columns.fileId == fileId).fetchAll(db)).map { record in
                BeamNoteReference(noteID: record.noteId, elementID: record.elementId)
            }
        }
    }

    func clearFileReferences() throws {
        _ = try write { db in
            try BeamFileRefRecord.deleteAll(db)
        }
    }

    func refresh(_ file: BeamFileRecord) async throws {
        do {
            if let remoteFile = try await self.refreshFromBeamObjectAPI(file, true) {
                try self.insert(files: [remoteFile])
            } else {
                Logger.shared.logError("Unable to get remoteFile \(file.id)", category: .fileDB)
            }
        } catch {
            Logger.shared.logError("Unable to refresh file \(file.id): \(error)", category: .fileDB)
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

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ files: [BeamFileRecord]) throws {
        try insert(files: files)
    }

    func allObjects(updatedSince: Date?) throws -> [BeamFileRecord] {
        try allRecords(updatedSince)
    }

    func saveAllOnNetwork(_ files: [BeamFileRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let localTimer = Date()
                try await self?.saveOnBeamObjectsAPI(files)
                Logger.shared.logDebug("Saved \(files.count) files on the BeamObject API",
                                       category: .fileNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the files on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ file: BeamFileRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let localTimer = Date()
                try await self?.saveOnBeamObjectAPI(file)
                Logger.shared.logDebug("Saved file \(file.name) on the BeamObject API",
                                       category: .fileNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the file on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
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

extension BeamData {
    var fileDBManager: BeamFileDBManager? {
        currentDatabase?.fileDBManager
    }
}
