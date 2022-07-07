//
//  TabGroupingStoreManager.swift
//  Beam
//
//  Created by Remi Santos on 13/06/2022.
//

import Foundation
import BeamCore
import GRDB

class TabGroupingStoreManager: GRDBHandler, BeamManager {

    static var id = UUID()
    static var name = "TabGroupingStoreManager"
    static var shared: TabGroupingStoreManager? { BeamData.shared.tabGroupingDBManager }

    override var tableNames: [String] { [TabGroupBeamObject.databaseTableName] }

    var holder: BeamManagerOwner?

    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    enum GroupUpdateOrigin {
        case clustering
        case userGroupMetadataChange
        case userGroupReordering
    }

    override func clear() throws {
        deleteAllGroups()
    }

    /// Will save the group in base if needed.
    ///
    /// Everytime a user manually interact with the group, with save the current state.
    /// If the group is updated by the clustering (adding/removing pages), we update only if we have more pages than the previous value.
    /// This makes a safety net where the user would not loose pages when closing tabs.
    /// - Returns: whether or not we decided to save the group
    @discardableResult
    func groupDidUpdate(_ group: TabGroup, origin: GroupUpdateOrigin, openTabs: [BrowserTab]) -> Bool {
        guard group.shouldBePersisted && group.title?.isEmpty == false else { return false }

        let existingValue = fetch(byIds: [group.id]).first
        if origin == .clustering, let existingValue = existingValue {
            let existingPagesIds = existingValue.pages.map { $0.id }
            if existingPagesIds == group.pageIds || existingPagesIds.count > group.pageIds.count {
                Logger.shared.logDebug("Not Saving Tab Group '\(group.title ?? "untitled")' because unimportant pages change", category: .tabGrouping)
                return false
            }
        }
        let pages: [TabGroupBeamObject.PageInfo] = group.pageIds.compactMap { id in
            guard let tab = openTabs.first(where: { $0.browsingTree.current.link == id }), let url = tab.url else { return nil }
            return TabGroupBeamObject.PageInfo(id: id, url: url, title: tab.title)
        }
        let object = convertGroupToBeamObject(group, pages: pages)
        Logger.shared.logInfo("Saving Tab Group '\(object.title ?? "untitled")' (\(pages.count) pages)", category: .tabGrouping)
        save(groups: [object])
        if AuthenticationManager.shared.isAuthenticated {
            do {
                try self.saveOnNetwork(object)
            } catch {
                Logger.shared.logError("Cannot send '\(object.title ?? "untitled")' (\(pages.count) pages): \(error)", category: .tabGrouping)
            }
        }
        return true
    }

    override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("createTabGroupTable") { db in
            try db.create(table: "TabGroup", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey().unique()
                t.column("title", .text).notNull()
                t.column("colorName", .text)
                t.column("colorHue", .double)
                t.column("pages", .blob).notNull()
                t.column("isLocked", .boolean).notNull()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("deletedAt", .datetime)
            }
        }
    }
}

private extension TabGroupingStoreManager {
    func convertGroupToBeamObject(_ group: TabGroup, pages: [TabGroupBeamObject.PageInfo]) -> TabGroupBeamObject {
        TabGroupBeamObject(id: group.id, title: group.title, color: group.color, pages: pages, isLocked: group.isLocked)
    }

    func convertBeamObjectToGroup(_ beamObject: TabGroupBeamObject) -> TabGroup {
        TabGroup(id: beamObject.id, pageIds: beamObject.pages.map { $0.id }, title: beamObject.title, color: beamObject.color, isLocked: beamObject.isLocked)
    }
}

// MARK: - Search
extension TabGroupingStoreManager {
    func searchGroups(forText searchTerm: String) -> [TabGroup] {
        let objects = fetch(byTitle: searchTerm)
        return objects.map { convertBeamObjectToGroup($0) }
    }
}

// MARK: - Synchronisation
extension TabGroupingStoreManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue = DispatchQueue(label: "TabGroupingStoreManager BeamObjectManager backgroundQueue", qos: .userInitiated)
    func willSaveAllOnBeamObjectApi() {}

    func manageConflict(_ object: TabGroupBeamObject, _ remoteObject: TabGroupBeamObject) throws -> TabGroupBeamObject {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ groups: [TabGroupBeamObject]) throws {
        save(groups: groups)
    }

    func receivedObjects(_ groups: [TabGroupBeamObject]) throws {
        save(groups: groups)
    }

    func allObjects(updatedSince: Date?) throws -> [TabGroupBeamObject] {
        allRecords(updatedSince)
    }

    func saveAllOnNetwork(_ groups: [TabGroupBeamObject], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectsAPI(groups)
                Logger.shared.logDebug("Saved tab groups on the BeamObject API", category: .tabGrouping)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the tab groups on the BeamObject API", category: .tabGrouping)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ group: TabGroupBeamObject, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.saveOnBeamObjectAPI(group)
                Logger.shared.logDebug("Saved tab group on the BeamObject API", category: .tabGrouping)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the tab group on the BeamObject API with error: \(error.localizedDescription)", category: .tabGrouping)
                networkCompletion?(.failure(error))
            }
        }
    }
}
// MARK: - Database
extension TabGroupingStoreManager {

    fileprivate func save(groups: [TabGroupBeamObject]) {
        do {
            try write { db in
                try groups.forEach { group in
                    var group = group
                    if group.pages.isEmpty {
                        try group.delete(db)
                    } else {
                        group.updatedAt = BeamDate.now
                        try group.save(db)
                    }
                }
            }
        } catch {
            Logger.shared.logError("Couldn't save tab groups, \(error)", category: .database)
        }
    }

    func allRecords(_ updatedSince: Date? = nil) -> [TabGroupBeamObject] {
        do {
            return try read { db in
                if let updatedSince = updatedSince {
                    return try TabGroupBeamObject.filter(TabGroupBeamObject.Columns.updatedAt >= updatedSince).fetchAll(db)
                }
                return try TabGroupBeamObject.fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups for updatedSince '\(String(describing: updatedSince))'. \(error)", category: .database)
            return []
        }
    }

    fileprivate func fetch(byIds ids: [UUID]) -> [TabGroupBeamObject] {
        do {
            return try read { db in
                return try TabGroupBeamObject
                    .filter(ids.contains(TabGroupBeamObject.Columns.id))
                    .order(TabGroupBeamObject.Columns.updatedAt.desc)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups for ids '\(ids)'. \(error)", category: .database)
            return []
        }
    }

    fileprivate func fetch(byTitle title: String) -> [TabGroupBeamObject] {
        let query = title.lowercased()
        do {
            return try read { db in
                return try TabGroupBeamObject
                    .filter(TabGroupBeamObject.Columns.title.like("%\(query)%"))
                    .order(TabGroupBeamObject.Columns.updatedAt.desc)
                    .limit(10)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups matching '\(query)'. \(error)", category: .database)
            return []
        }
    }

    fileprivate func deleteAllGroups() {
        do {
            _ = try write { db in
                try TabGroupBeamObject.deleteAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't delete all tab groups", category: .database)
        }
    }
}

extension BeamManagerOwner {
    var tabGroupingDBManager: TabGroupingStoreManager? {
        try? manager(TabGroupingStoreManager.self)
    }
}

extension BeamData {
    var tabGroupingDBManager: TabGroupingStoreManager? {
        currentAccount?.tabGroupingDBManager
    }
}
