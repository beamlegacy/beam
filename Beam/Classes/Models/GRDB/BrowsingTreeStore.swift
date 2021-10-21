//
//  BrowsingTreeRecord.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 05/10/2021.
//

import Foundation
import BeamCore
import GRDB
import SwiftUI

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

struct BrowsingTreeRecord: Decodable, BeamObjectProtocol {
    static var beamObjectTypeName = "browsingTree"

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
    var previousChecksum: String?
    var checksum: String?
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
            deletedAt: deletedAt,
            previousChecksum: previousChecksum
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
        previousChecksum = row[Columns.previousChecksum]
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
        container[Columns.previousChecksum] = previousChecksum
    }
}

extension BrowsingTreeRecord: TableRecord {
    /// The table columns
    enum Columns: String, ColumnExpression {
        case rootId, rootCreatedAt, appSessionId, data, createdAt, updatedAt, deletedAt, previousChecksum
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

    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil) throws {
        guard let record = browsingTree.toRecord(appSessionId: appSessionId) else { return }
        try db.save(browsingTreeRecord: record)
        if AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled {
            try self.saveOnNetwork(record)
        }
    }
    func save(browsingTree: BrowsingTree, appSessionId: UUID? = nil, completion:  @escaping () -> Void) {
        DispatchQueue.global().async {
            do {
                try BrowsingTreeStoreManager.shared.save(browsingTree: browsingTree, appSessionId: appSessionId)
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
}
enum BrowsingTreeStoreManagerError: Error, Equatable {
    case localFileNotFound
}

extension BrowsingTreeStoreManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace

    func willSaveAllOnBeamObjectApi() {}

    func receivedObjects(_ records: [BrowsingTreeRecord]) throws {
        try save(browsingTreeRecords: records)
    }

    func allObjects(updatedSince: Date?) throws -> [BrowsingTreeRecord] {
        try getAllBrowsingTrees(updatedSince: updatedSince)
    }

    func checksumsForIds(_ rootIds: [UUID]) throws -> [UUID: String] {
        let values: [(UUID, String)] = try getBrowsingTrees(rootIds: rootIds).compactMap {
            guard let previousChecksum = $0.previousChecksum else { return nil }
            return ($0.rootId, previousChecksum)
        }
        return Dictionary(uniqueKeysWithValues: values)
    }

    private func saveOnNetwork(_ record: BrowsingTreeRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        let localTimer = BeamDate.now
        try self.saveOnBeamObjectAPI(record) { result in
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
    }

    func saveAllOnNetwork(_ records: [BrowsingTreeRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        let localTimer = BeamDate.now

        try self.saveOnBeamObjectsAPI(records) { result in
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
    }

    func persistChecksum(_ records: [BrowsingTreeRecord]) throws {
        Logger.shared.logDebug("Saved \(records.count) BeamObject checksums",
                               category: .fileNetwork)
        if try !(records.allSatisfy { try exists(browsingTreeRecord: $0) }) {
            throw BrowsingTreeStoreManagerError.localFileNotFound
        }
        try save(browsingTreeRecords: records)
    }

    func manageConflict(_ object: BrowsingTreeRecord,
                        _ remoteObject: BrowsingTreeRecord) throws -> BrowsingTreeRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [BrowsingTreeRecord]) throws {
        try save(browsingTreeRecords: objects)
    }
}
