//
//  TabGroupingStoreManager.swift
//  Beam
//
//  Created by Remi Santos on 13/06/2022.
//

import Foundation
import BeamCore

class TabGroupingStoreManager {

    static var shared = TabGroupingStoreManager()
    private let store: TabGroupsStore

    init(store: TabGroupsStore = TabGroupsStore()) {
        self.store = store
    }

    enum GroupUpdateOrigin {
        case clustering
        case userGroupMetadataChange
        case userGroupReordering
    }

    func clearData() {
        store.cleanup()
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

        let existingValue = store.fetch(byIds: [group.id]).first
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
        store.save(object)
        return true
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
        let objects = store.fetch(byTitle: searchTerm)
        return objects.map { convertBeamObjectToGroup($0) }
    }
}
