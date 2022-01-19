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
            data: self
        )
    }
}
extension BrowsingTree: DatabaseValueConvertible {}

extension BrowsingTree: Equatable {
    static public func == (lhs: BrowsingTree, rhs: BrowsingTree) -> Bool {
        lhs.rootId == rhs.rootId
    }
}

extension BrowsingTree: Hashable {
    public func hash(into hasher: inout Hasher) {
       hasher.combine(rootId)
    }
}

struct BrowsingTreeRecord: Decodable, BeamObjectProtocol {
    static var beamObjectType = BeamObjectObjectType.browsingTree

    public enum CodingKeys: String, CodingKey {
        case rootId, rootCreatedAt, appSessionId, data, createdAt, updatedAt, deletedAt
    }

    var rootId: UUID
    let rootCreatedAt: Date
    let appSessionId: UUID?
    var data: BrowsingTree

    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?
    var beamObjectId: UUID {
        get { rootId }
        set { rootId = newValue }
    }

    func copy() throws -> BrowsingTreeRecord {
        return BrowsingTreeRecord(
            rootId: rootId,
            rootCreatedAt: rootCreatedAt,
            appSessionId: appSessionId,
            data: data,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
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
        data = row[Columns.data]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
    }
}

extension BrowsingTreeRecord: PersistableRecord {
    func encode(to container: inout PersistenceContainer) {
        container[Columns.rootId] = rootId
        container[Columns.rootCreatedAt] = rootCreatedAt
        container[Columns.appSessionId] = appSessionId
        container[Columns.data] = data
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
    }
}

extension BrowsingTreeRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case rootId, rootCreatedAt, appSessionId, data, createdAt, updatedAt, deletedAt
    }
}

protocol BrowsingTreeStoreProtocol {
    func save(browsingTree: BrowsingTree, appSessionId: UUID?) throws
    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord?
    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord]
}

class BrowsingTreeStoreManager: BrowsingTreeStoreProtocol {
    let db: GRDBDatabase
    public let group = DispatchGroup()
    static let shared = BrowsingTreeStoreManager()
    let groupTimeOut: Double = 2
    let treeProcessor = BrowsingTreeProcessor()

    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    func process(tree: BrowsingTree) {
        treeProcessor.process(tree: tree)
    }
    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil) throws {
        guard let record = browsingTree.toRecord(appSessionId: appSessionId) else { return }
        try db.save(browsingTreeRecord: record)
        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            try self.saveOnNetwork(record)
        }
    }
    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil, completion:  @escaping () -> Void) {
        DispatchQueue.global().async { [weak self] in
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
        try db.save(browsingTreeRecords: browsingTreeRecords)
    }

    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord? {
        try db.getBrowsingTree(rootId: rootId)
    }

    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord] {
        try db.getBrowsingTrees(rootIds: rootIds)
    }

    func getAllBrowsingTrees(updatedSince: Date? = nil) throws -> [BrowsingTreeRecord] {
        try db.getAllBrowsingTrees(updatedSince: updatedSince)
    }

    func exists(browsingTreeRecord: BrowsingTreeRecord) throws -> Bool {
        try db.exists(browsingTreeRecord: browsingTreeRecord)
    }
    func browsingTreeExists(rootId: UUID) throws -> Bool {
        try db.browsingTreeExists(rootId: rootId)
    }

    var countBrowsingTrees: Int? {
        db.countBrowsingTrees
    }

    func clearBrowsingTrees() throws {
        try db.clearBrowsingTrees()
    }
    func delete(id: UUID) throws {
        try db.deleteBrowsingTree(id: id)
    }
    func delete(ids: [UUID]) throws {
        try db.deleteBrowsingTrees(ids: ids)
    }

    func remoteDeleteAll(_ completion: ((Result<Bool, Error>) -> Void)? = nil) {
        Logger.shared.logInfo("Deleting browsing trees from API", category: .browsingTreeNetwork)
        do {
            try BrowsingTreeStoreManager.shared.deleteAllFromBeamObjectAPI { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
                    completion?(.failure(error))
                case .success:
                    Logger.shared.logInfo("Succesfully deleted browsing trees from API", category: .browsingTreeNetwork)
                    completion?(.success(true))
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
            completion?(.failure(error))
        }
    }
}
enum BrowsingTreeStoreManagerError: Error, Equatable {
    case localFileNotFound
}

extension BrowsingTreeStoreManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue: DispatchQueue = DispatchQueue(label: "BrowsingTreeStoreManager BeamObjectManager backgroundQueue", qos: .userInitiated)

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ records: [BrowsingTreeRecord]) throws {
        let newRecords = try records.filter { try !db.exists(browsingTreeRecord: $0) }
        for rec in newRecords {
            process(tree: rec.data)
        }
        try save(browsingTreeRecords: records)
    }

    func allObjects(updatedSince: Date?) throws -> [BrowsingTreeRecord] {
        try getAllBrowsingTrees(updatedSince: updatedSince)
    }

    private func saveOnNetwork(_ record: BrowsingTreeRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                let localTimer = BeamDate.now
                try self?.saveOnBeamObjectAPI(record) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved tree \(record.rootId) on the BeamObject API",
                                               category: .fileNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the tree on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .fileNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
            }
        }
    }

    func saveAllOnNetwork(_ records: [BrowsingTreeRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                let localTimer = BeamDate.now
                try self?.saveOnBeamObjectsAPI(records) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved \(records.count) trees on the BeamObject API",
                                               category: .fileNetwork,
                                               localTimer: localTimer)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving the trees on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .fileNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .fileNetwork)
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
            let tree = record.data
            return tree.root.legacy ? record : nil
        }
        if legacyObjects.isEmpty {
            Logger.shared.logInfo("No legacy tree to clean", category: .browsingTreeNetwork)
            return
        }
        //local cleanup
        do {
            try delete(ids: legacyObjects.compactMap { $0.id })
            Logger.shared.logInfo("Succesfully locally deleted \(legacyObjects.count) legacy tree(s) ",
                                  category: .browsingTreeNetwork)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
            completion?(.failure(error))
            return
        }
        //remote cleanup
        do {
            try BrowsingTreeStoreManager.shared.deleteFromBeamObjectAPI(objects: legacyObjects) { result in
                switch result {
                case .failure(let error):
                    Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
                    completion?(.failure(error))
                case .success:
                    Logger.shared.logInfo("Succesfully deleted \(legacyObjects.count) legacy tree(s) from API", category: .browsingTreeNetwork)
                    completion?(.success(true))
                }
            }
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .browsingTreeNetwork)
            completion?(.failure(error))
        }
    }
}
