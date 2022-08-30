//
//  BrowsingTreeRecord.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 05/10/2021.
//

import Foundation
import BeamCore
import GRDB

extension BrowsingTree {
    func toRecord(appSessionId: UUID? = nil) -> BrowsingTreeRecord? {
        guard
            let root = root,
            let rootCreatedAt = root.events.first?.date else { return nil }
        return BrowsingTreeRecord(
            rootId: root.id,
            rootCreatedAt: rootCreatedAt,
            appSessionId: appSessionId,
            flattenedData: self.flattened
        )
    }
}
extension BrowsingTree: DatabaseValueConvertible {}
extension FlatennedBrowsingTree: DatabaseValueConvertible {}

extension BrowsingTree: Equatable {
    static public func == (lhs: BrowsingTree, rhs: BrowsingTree) -> Bool {
        lhs.rootId == rhs.rootId
    }
}
extension FlatennedBrowsingTree: Equatable {
    static public func == (lhs: FlatennedBrowsingTree, rhs: FlatennedBrowsingTree) -> Bool {
        lhs.root?.id == rhs.root?.id
    }
}

extension BrowsingTree: Hashable {
    public func hash(into hasher: inout Hasher) {
       hasher.combine(rootId)
    }
}

extension FlatennedBrowsingTree: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(root?.id)
    }
}

struct BrowsingTreeRecord: Decodable, BeamObjectProtocol {

    enum ProcessingStatus: Int, Codable, DatabaseValueConvertible {
        case toDo = 0
        case started = 1
        case done = 2
    }

    static var beamObjectType = BeamObjectObjectType.browsingTree

    public enum CodingKeys: String, CodingKey {
        case rootId, rootCreatedAt, appSessionId, data, flattenedData, createdAt, updatedAt, deletedAt
    }

    var rootId: UUID
    let rootCreatedAt: Date
    let appSessionId: UUID?
    var data: BrowsingTree?
    var flattenedData: FlatennedBrowsingTree?

    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?
    var processingStatus: ProcessingStatus = .done
    var beamObjectId: UUID {
        get { rootId }
        set { rootId = newValue }
    }
    var flattened: BrowsingTreeRecord {
        BrowsingTreeRecord(
            rootId: rootId,
            rootCreatedAt: rootCreatedAt,
            appSessionId: appSessionId,
            data: nil,
            flattenedData: flattenedData ?? data?.flattened,
            createdAt: createdAt,
            updatedAt: flattenedData == nil ? BeamDate.now : updatedAt, //triggers a later upward sync if data was unflattened
            deletedAt: deletedAt
        )
    }

    func copy() throws -> BrowsingTreeRecord {
        return BrowsingTreeRecord(
            rootId: rootId,
            rootCreatedAt: rootCreatedAt,
            appSessionId: appSessionId,
            data: data,
            flattenedData: flattenedData,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            processingStatus: processingStatus
        )
    }
}

extension BrowsingTreeRecord: Identifiable {
    public var id: UUID { rootId }
}

extension BrowsingTreeRecord: FetchableRecord {
    /// Creates a record from a database row
    init(row: Row) {
        rootId = row[Columns.rootId]
        rootCreatedAt = row[Columns.rootCreatedAt]
        appSessionId = row[Columns.appSessionId]
        flattenedData = row[Columns.flattenedData]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
        processingStatus = row[Columns.processingStatus]
    }
}

extension BrowsingTreeRecord: PersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container[Columns.rootId] = rootId
        container[Columns.rootCreatedAt] = rootCreatedAt
        container[Columns.appSessionId] = appSessionId
        container[Columns.flattenedData] = flattenedData
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
        container[Columns.processingStatus] = processingStatus
    }
}

extension BrowsingTreeRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case rootId, rootCreatedAt, appSessionId, flattenedData, processingStatus, createdAt, updatedAt, deletedAt
    }
}

protocol BrowsingTreeStoreProtocol {
    func save(browsingTree: BrowsingTree, appSessionId: UUID?) throws
    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord?
    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord]
}

class BrowsingTreeStoreManager: BrowsingTreeStoreProtocol {
    let objectManager: BeamObjectManager

    var changedObjects: [UUID : BrowsingTreeRecord] = [:]
    let objectQueue = BeamObjectQueue<BrowsingTreeRecord>()
    let providedDb: BrowsingTreeDBManager?
    var db: BrowsingTreeDBManager? {
        let currentDb = providedDb ?? BeamData.shared.browsingTreeDBManager
        if currentDb == nil {
            Logger.shared.logError("BrowswingTreeStore has no BrowsingTreeDBManager available", category: .browsingTreeNetwork)
        }
        return currentDb
    }
    public var treeProcessingCompleted = false
    public let group = DispatchGroup()
    let groupTimeOut: Double = 2
    let treeProcessor = BrowsingTreeProcessor()

    init(db: BrowsingTreeDBManager? = nil, objectManager: BeamObjectManager) {
        self.objectManager = objectManager
        self.providedDb = db

        if Configuration.browsingTreeApiSyncEnabled {
            registerOnBeamObjectManager(objectManager)
        }
    }

    func process(tree: BrowsingTree) {
        treeProcessor.process(tree: tree)
    }
    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil) throws {
        guard let db = db, let record = browsingTree.toRecord(appSessionId: appSessionId) else { return }
        try db.save(browsingTreeRecord: record)
        if AuthenticationManager.shared.isAuthenticated,
            Configuration.networkEnabled,
            Configuration.browsingTreeApiSyncEnabled {
            try self.saveOnNetwork(record)
        }
    }
    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil, completion:  @escaping () -> Void) {
        DispatchQueue.database.async { [weak self] in
            do {
                try self?.save(browsingTree: browsingTree, appSessionId: appSessionId)
                completion()
            } catch {
                Logger.shared.logError("Couldn't save tree with id: \(browsingTree.root.id) in db", category: .database)
                completion()
            }
        }
    }
    func groupSave(browsingTree: BrowsingTree, appSessionId: UUID? = nil) {
        group.enter()
        save(browsingTree: browsingTree, appSessionId: appSessionId) { [weak self] in self?.group.leave() }
    }

    func groupWait() -> DispatchTimeoutResult {
        let result = group.wait(timeout: .now() + groupTimeOut)
        switch result {
        case .timedOut: Logger.shared.logWarning("Some browsing trees may not have been saved before timeout", category: .database)
        case .success: Logger.shared.logInfo("All browsing trees save tasks completed before timeout", category: .database)
        }
        return result
    }

    func save(browsingTreeRecords: [BrowsingTreeRecord]) throws {
        guard let db = db else { return }
        try db.save(browsingTreeRecords: browsingTreeRecords)
    }

    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord? {
        guard let db = db else { return nil }
        return try db.getBrowsingTree(rootId: rootId)
    }

    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord] {
        guard let db = db else { return [] }
        return try db.getBrowsingTrees(rootIds: rootIds)
    }

    func getAllBrowsingTrees(updatedSince: Date? = nil) throws -> [BrowsingTreeRecord] {
        guard let db = db else { return [] }
        return try db.getAllBrowsingTrees(updatedSince: updatedSince)
    }

    func exists(browsingTreeRecord: BrowsingTreeRecord) throws -> Bool {
        guard let db = db else { return false }
        return try db.exists(browsingTreeRecord: browsingTreeRecord)
    }
    func browsingTreeExists(rootId: UUID) throws -> Bool {
        guard let db = db else { return false }
        return try db.browsingTreeExists(rootId: rootId)
    }

    var countBrowsingTrees: Int? {
        db?.countBrowsingTrees
    }

    func clearBrowsingTrees() throws {
        guard let db = db else { return }
        try db.clearBrowsingTrees()
    }
    func delete(id: UUID) throws {
        guard let db = db else { return }
        try db.deleteBrowsingTree(id: id)
    }
    func delete(ids: [UUID]) throws {
        guard let db = db else { return }
        try db.deleteBrowsingTrees(ids: ids)
    }
    func softDelete(olderThan days: Int = 60, maxRows: Int = 20 * 1000) {
        guard let db = db else { return }
        do {
            try db.softDeleteBrowsingTrees(olderThan: days, maxRows: maxRows)

        } catch {
            Logger.shared.logError("Couldn't soft delete browsing trees: \(error)", category: .database)
        }
    }

    func remoteDeleteAll(_ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logInfo("Deleting browsing trees from API", category: .browsingTreeNetwork)
        Task {
            do {
                try await deleteAllFromBeamObjectAPI()
                completion?(.success(true))
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .database)
                completion?(.failure(error))
            }
        }
    }
}
enum BrowsingTreeStoreManagerError: Error, Equatable {
    case localFileNotFound
}

extension BrowsingTreeStoreManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ records: [BrowsingTreeRecord]) throws {
        guard let db = db else { return }
        treeProcessingCompleted = false
        let statuses = db.browsingTreeProcessingStatuses(ids: records.map { $0.rootId })
        let flattenedRecordsWithDbStatus = records.map { (record) -> BrowsingTreeRecord in
            var newRecord = record.flattened
            newRecord.processingStatus = statuses[record.rootId] ?? .toDo //record not already in db are to be processed
            return newRecord
        }
        try save(browsingTreeRecords: flattenedRecordsWithDbStatus)
        let recordsToProcess = flattenedRecordsWithDbStatus.filter { $0.processingStatus == .toDo }
        DispatchQueue.database.async {
            for record in recordsToProcess {
                guard let db = self.db else { return }
                if let flattenedTree = record.flattenedData,
                   let tree = BrowsingTree(flattenedTree: flattenedTree) {
                    db.update(record: record, status: .started)
                    self.process(tree: tree)
                    db.update(record: record, status: .done)
                }
            }
            self.treeProcessingCompleted = true
        }
    }

    func allObjects(updatedSince: Date?) throws -> [BrowsingTreeRecord] {
        try getAllBrowsingTrees(updatedSince: updatedSince)
    }

    private func saveOnNetwork(_ record: BrowsingTreeRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let localTimer = Date()
                try await saveOnBeamObjectAPI(record)
                Logger.shared.logDebug("Saved tree \(record.rootId) on the BeamObject API",
                                       category: .fileNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the tree on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    func saveAllOnNetwork(_ records: [BrowsingTreeRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let localTimer = Date()
                try await saveOnBeamObjectsAPI(records)
                Logger.shared.logDebug("Saved \(records.count) trees on the BeamObject API",
                                       category: .fileNetwork,
                                       localTimer: localTimer)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the trees on the BeamObject API with error: \(error.localizedDescription)",
                                       category: .fileNetwork)
                networkCompletion?(.failure(error))
            }
        }
    }

    func manageConflict(_ object: BrowsingTreeRecord,
                        _ remoteObject: BrowsingTreeRecord) throws -> BrowsingTreeRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [BrowsingTreeRecord]) throws {
        try save(browsingTreeRecords: objects)
    }
}

extension BrowsingTreeStoreManager {
    func legacyCleanup(_ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logInfo("Cleaning legacy browsing trees", category: .browsingTreeNetwork)
        var treeRecords = [BrowsingTreeRecord]()
        do {
            treeRecords = try getAllBrowsingTrees()
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
            completion?(.failure(error))
            return
        }
        let legacyObjects = treeRecords.compactMap { record -> BrowsingTreeRecord? in
            guard let flattenedTree = record.flattenedData,
            let root = flattenedTree.root else { return nil }
            return root.legacy ? record : nil
        }
        if legacyObjects.isEmpty {
            Logger.shared.logInfo("No legacy tree to clean", category: .browsingTreeNetwork)
            completion?(.success(true))
            return
        }
        //local cleanup
        do {
            try delete(ids: legacyObjects.compactMap { $0.id })
            Logger.shared.logInfo("Successfully locally deleted \(legacyObjects.count) legacy tree(s) ",
                                  category: .browsingTreeNetwork)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
            completion?(.failure(error))
            return
        }
        //remote cleanup
        Task {
            do {
                try await deleteFromBeamObjectAPI(objects: legacyObjects)
                Logger.shared.logInfo("Successfully deleted \(legacyObjects.count) legacy tree(s) from API", category: .browsingTreeNetwork)
                completion?(.success(true))
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
                completion?(.failure(error))
            }
        }
    }
}
