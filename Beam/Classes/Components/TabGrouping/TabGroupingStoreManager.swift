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
    var changedObjects: [UUID: TabGroupBeamObject] = [:]
    let objectQueue = BeamObjectQueue<TabGroupBeamObject>()

    static var id = UUID()
    static var name = "TabGroupingStoreManager"

    override var tableNames: [String] { [TabGroupBeamObject.databaseTableName] }

    weak var holder: BeamManagerOwner?
    let objectManager: BeamObjectManager

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.holder = holder
        self.objectManager = objectManager
        try super.init(store: store)

        registerOnBeamObjectManager(objectManager)
    }

    enum GroupUpdateOrigin {
        case clustering
        case userGroupMetadataChange
        case userGroupReordering
        case sharing
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
    func groupDidUpdate(_ group: TabGroup, origin: GroupUpdateOrigin, updatePagesWithOpenedTabs openedTabs: [BrowserTab]?) async -> Bool {
        guard group.shouldBePersisted && group.title?.isEmpty == false else { return false }

        let existingValue = fetch(byIds: [group.id]).first
        if origin == .clustering, let existingValue = existingValue {
            let existingPagesIds = existingValue.pages.map { $0.id }
            if group.isLocked || existingPagesIds.count > group.pageIds.count || Set(existingPagesIds) == Set(group.pageIds) {
                Logger.shared.logDebug("Not Saving Tab Group '\(group.title ?? "untitled")' because unimportant pages change", category: .tabGrouping)
                return false
            }
        }

        let pages: [TabGroupBeamObject.PageInfo]
        if let openedTabs = openedTabs, !openedTabs.isEmpty {
            pages = await buildPagesInfos(for: group, with: openedTabs)
        } else {
            let existingPages = existingValue?.pages
            pages = group.pageIds.compactMap { id in
                if let existingPage = existingPages?.first(where: { $0.id == id }) {
                    return existingPage
                }
                if let link = LinkStore.linkFor(id), let url = URL(string: link.url) {
                    return TabGroupBeamObject.PageInfo(id: id, url: url, title: link.title ?? link.url)
                }
                return nil
            }
        }

        let object = Self.convertGroupToBeamObject(group, pages: pages)
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

    private func buildPagesInfos(for group: TabGroup, with openedTabs: [BrowserTab]) async -> [TabGroupBeamObject.PageInfo] {
        sortPageIdsInGroup(group, withOpenTabs: openedTabs)

        let tabs: [(BrowserTab, UUID) ] = group.pageIds.compactMap { id -> (BrowserTab, UUID)? in
            guard let tab = openedTabs.first(where: { $0.pageId == id }), tab.url != nil else { return nil }
            return (tab, id)
        }

        let screenshots = group.isLocked ? await screenshots(for: tabs) : [:]

        return tabs.compactMap { (tab, id) -> TabGroupBeamObject.PageInfo? in
            guard let url = tab.url else { return nil }
            var snapshotData: Data?
            if let snapshot = screenshots[tab], snapshot.isValid {
                snapshotData = snapshot.jpegRepresentation
            }
            return TabGroupBeamObject.PageInfo(id: id, url: url, title: tab.title, snapshot: snapshotData)
        }
    }

    func deleteGroup(_ group: TabGroup, deleteParentIfRelevant: Bool = false) {
        guard let object = fetch(byIds: [group.id]).first else { return }
        let parentId = group.parentGroup
        delete(groups: [object])
        // if the group is a pure copy of its parent, we can delete the parent too.
        guard deleteParentIfRelevant, let parentId = parentId else { return }
        fetch(byIds: [parentId]).forEach { parent in
            guard object.isACopy(of: parent), !parent.isLocked else { return }
            delete(groups: [parent])
        }
    }

    private func sortPageIdsInGroup(_ group: TabGroup, withOpenTabs openTabs: [BrowserTab]) {
        var groupPageIds = group.pageIds
        var sortedPageIds = [ClusteringManager.PageID]()
        openTabs.forEach { tab in
            guard let index = groupPageIds.firstIndex(where: { $0 == tab.pageId }) else { return }
            let pageId = groupPageIds.remove(at: index)
            sortedPageIds.append(pageId)
        }
        sortedPageIds.append(contentsOf: groupPageIds)
        group.updatePageIds(sortedPageIds)
    }

    private func screenshots(for tabs: [(BrowserTab, UUID)]) async -> [BrowserTab: NSImage] {
        var screenshots: [BrowserTab: NSImage] = [:]
        for (tab, _) in tabs {
            if let screenshot = await tab.screenshotTab() {
                screenshots[tab] = screenshot
            }
        }
        return screenshots
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
        migrator.registerMigration("addParentGroupColumn") { db in
            try db.alter(table: "TabGroup") { t in
                t.add(column: "parentGroup", .text)
            }
        }
    }
}

extension TabGroupingStoreManager {
    static func convertGroupToBeamObject(_ group: TabGroup, pages: [TabGroupBeamObject.PageInfo]) -> TabGroupBeamObject {
        TabGroupBeamObject(id: group.id, title: group.title, color: group.color, pages: pages, isLocked: group.isLocked, parentGroup: group.parentGroup)
    }

    static func convertBeamObjectToGroup(_ beamObject: TabGroupBeamObject) -> TabGroup {
        TabGroup(id: beamObject.id, pageIds: beamObject.pages.map { $0.id }, title: beamObject.title, color: beamObject.color, isLocked: beamObject.isLocked, parentGroup: beamObject.parentGroup)
    }

    static func suggestedDefaultTitle(for group: TabGroup, withTabs tabs: [BrowserTab]? = nil, truncated: Bool) -> String {
        let firstPageTitle: String
        if let firstTab = tabs?.first {
            firstPageTitle = firstTab.title
        } else if let firstPage = group.pageIds.first, let link = LinkStore.shared.getLinks(for: [firstPage]).first?.value {
            firstPageTitle = link.title ?? ""
        } else {
            return "Empty Tab Group"
        }
        var result: String = ""
        let count = tabs?.count ?? group.pageIds.count
        if !firstPageTitle.isEmpty {
            if truncated {
                result = "”\(firstPageTitle.truncated(limit: 25, position: .tail))”"
            } else {
                result = firstPageTitle
            }

            if count > 1 {
                result += " & \(count - 1) more"
            }
        } else {
            result = "\(count) grouped tab\(count > 1 ? "s" : "")"
        }
        return result
    }
}

// MARK: - Search
extension TabGroupingStoreManager {
    func searchGroups(forText searchTerm: String) -> [TabGroup] {
        let objects = fetch(byTitle: searchTerm)
        return objects.map { Self.convertBeamObjectToGroup($0) }
    }
}

// MARK: - Synchronisation
extension TabGroupingStoreManager: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    static var uploadType: BeamObjectRequestUploadType {
        Configuration.directUploadAllObjects ? .directUpload : .multipartUpload
    }
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
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try await saveOnBeamObjectsAPI(groups)
                Logger.shared.logDebug("Saved tab groups on the BeamObject API", category: .tabGrouping)
                networkCompletion?(.success(true))
            } catch {
                Logger.shared.logDebug("Error when saving the tab groups on the BeamObject API", category: .tabGrouping)
                networkCompletion?(.failure(error))
            }
        }
    }

    private func saveOnNetwork(_ group: TabGroupBeamObject, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try await saveOnBeamObjectAPI(group)
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

    func makeLockedCopy(_ group: TabGroup, title: String) -> TabGroup? {
        guard let beamObject = fetch(byIds: [group.id]).first else { return nil }
        var copy = beamObject.makeLockedCopy()
        copy.title = title
        save(groups: [copy])
        return Self.convertBeamObjectToGroup(copy)
    }

    func delete(groups: [TabGroupBeamObject]) {
        do {
            try write { db in
                try groups.forEach { group in
                    try group.delete(db)
                }
            }
        } catch {
            Logger.shared.logError("Couldn't delete tab groups, \(error)", category: .database)
        }
    }

    func save(groups: [TabGroupBeamObject]) {
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

    func fetch(byIds ids: [UUID]) -> [TabGroupBeamObject] {
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

    func fetch(copiesOfGroup tabGroupId: UUID) -> [TabGroupBeamObject] {
        do {
            return try read { db in
                return try TabGroupBeamObject
                    .filter(TabGroupBeamObject.Columns.parentGroup == tabGroupId)
                    .order(TabGroupBeamObject.Columns.updatedAt.desc)
                    .fetchAll(db)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch tab groups copied from '\(tabGroupId)'. \(error)", category: .database)
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

private extension TabGroupBeamObject {
    func makeLockedCopy() -> TabGroupBeamObject {
        TabGroupBeamObject(title: title, color: color, pages: pages, isLocked: true, parentGroup: id,
                           createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt)
    }
}

extension BeamManagerOwner {
    var tabGroupingDBManager: TabGroupingStoreManager? {
        try? manager(TabGroupingStoreManager.self)
    }
}

extension BeamData {
    var tabGroupingDBManager: TabGroupingStoreManager? {
        AppData.shared.currentAccount?.tabGroupingDBManager
    }
}
