//
//  BrowsingTreeDBManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 07/06/2022.
//

import Foundation
import GRDB
import BeamCore

class BrowsingTreeDBManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    static var id = UUID()

    static var name = "BrowsingTreeDBManager"

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override var tableNames: [String] { ["BrowsingTreeRecord"] }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("createBrowsingTreeRecordTable") { db in
            try db.create(table: "BrowsingTreeRecord", ifNotExists: true) { t in
                t.column("rootId", .text).primaryKey()
                t.column("rootCreatedAt", .date).indexed().notNull()
                t.column("appSessionId", .text)
                t.column("flattenedData", .blob) //not null constraint dropped
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
                t.column("processingStatus", .integer).notNull().indexed().defaults(to: 2)
            }
        }
    }

    func save(browsingTreeRecord: BrowsingTreeRecord) throws {
        do {
            try self.write { db in try browsingTreeRecord.save(db) }
        } catch {
            Logger.shared.logError("Couldn't save tree with id \(browsingTreeRecord.rootId)", category: .database)
            throw error
        }
    }
    func save(browsingTreeRecords: [BrowsingTreeRecord]) throws {
        do {
            try self.write { db in
                try browsingTreeRecords.forEach { (record) in try record.save(db) }
            }
        } catch {
            Logger.shared.logError("Couldn't save trees \(browsingTreeRecords)", category: .database)
            throw error
        }
    }
    func getBrowsingTree(rootId: UUID) throws -> BrowsingTreeRecord? {
        try self.read { db in try BrowsingTreeRecord.fetchOne(db, id: rootId) }
    }
    func getBrowsingTrees(rootIds: [UUID]) throws -> [BrowsingTreeRecord] {
        try self.read { db in try BrowsingTreeRecord.fetchAll(db, ids: rootIds) }
    }
    func getAllBrowsingTrees(updatedSince: Date? = nil) throws -> [BrowsingTreeRecord] {
        try self.read { db in
            if let updatedSince = updatedSince {
                return try BrowsingTreeRecord.filter(BrowsingTreeRecord.Columns.updatedAt >= updatedSince).fetchAll(db)
            }
            return try BrowsingTreeRecord.fetchAll(db)
        }
    }
    func exists(browsingTreeRecord: BrowsingTreeRecord) throws -> Bool {
        try self.read { db in
            try browsingTreeRecord.exists(db)
        }
    }
    func browsingTreeExists(rootId: UUID) throws -> Bool {
        try self.read { db in
            try BrowsingTreeRecord.filter(id: rootId).fetchCount(db) > 0
        }
    }
    var countBrowsingTrees: Int? {
        return try? self.read { db in try BrowsingTreeRecord.fetchCount(db) }
    }
    func clearBrowsingTrees() throws {
        _ = try self.write { db in
            try BrowsingTreeRecord.deleteAll(db)
        }
    }
    func deleteBrowsingTree(id: UUID) throws {
        _ = try self.write { db in
            try BrowsingTreeRecord.deleteOne(db, id: id)
        }
    }
    func deleteBrowsingTrees(ids: [UUID]) throws {
        _ = try self.write { db in
            try BrowsingTreeRecord.deleteAll(db, ids: ids)
        }
    }
    func browsingTreeProcessingStatuses(ids: [UUID]) -> [UUID: BrowsingTreeRecord.ProcessingStatus] {
        (try? self.read { (db) -> [UUID: BrowsingTreeRecord.ProcessingStatus]? in
            let cursor = try BrowsingTreeRecord.fetchCursor(db).map { ($0.rootId, $0.processingStatus) }
            let statuses: [UUID: BrowsingTreeRecord.ProcessingStatus]? = try? Dictionary(uniqueKeysWithValues: cursor)
            return statuses
        }) ?? [UUID: BrowsingTreeRecord.ProcessingStatus]()
    }
    func update(record: BrowsingTreeRecord, status: BrowsingTreeRecord.ProcessingStatus) {
        var updatedRecord = record
        updatedRecord.processingStatus = status
        do {
            _ = try self.write { db in
                try updatedRecord.updateChanges(db, from: record)
            }
        } catch {
            Logger.shared.logInfo("Couldn't update tree record id: \(record.rootId) \(error)", category: .browsingTreeNetwork)
        }

    }
    func softDeleteBrowsingTrees(olderThan days: Int, maxRows: Int) throws {
        let now = BeamDate.now
        let timeCond = BrowsingTreeRecord.Columns.rootCreatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = BrowsingTreeRecord.select(BrowsingTreeRecord.Columns.rootId)
            .order(BrowsingTreeRecord.Columns.rootCreatedAt.desc)
            .limit(maxRows)

        try _ = self.write { db in
            try BrowsingTreeRecord
                .filter(timeCond || !rankSubQuery.contains(BrowsingTreeRecord.Columns.rootId))
                .updateAll(db,
                           BrowsingTreeRecord.Columns.deletedAt.set(to: now),
                           BrowsingTreeRecord.Columns.updatedAt.set(to: now),
                           BrowsingTreeRecord.Columns.flattenedData.set(to: nil)
                )
        }
    }
}

extension BeamManagerOwner {
    var browsingTreeDBManager: BrowsingTreeDBManager? {
        try? manager(BrowsingTreeDBManager.self)
    }
}

extension BeamData {
    var browsingTreeDBManager: BrowsingTreeDBManager? {
        AppData.shared.currentAccount?.browsingTreeDBManager
    }
}
