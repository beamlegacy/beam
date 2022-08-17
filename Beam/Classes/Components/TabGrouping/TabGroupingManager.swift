import Foundation
import BeamCore

struct TabForcedGroup {
    var inGroup: TabGroup?
    var outOfGroup: TabGroup?

    mutating func update(inGroup: TabGroup?, outOfGroup: TabGroup? = nil) {
        if inGroup != nil {
            self.outOfGroup = nil
        }
        self.inGroup = inGroup
        if outOfGroup != inGroup || outOfGroup == nil {
            self.outOfGroup = outOfGroup
        }
    }
}

protocol TabGroupingManagerDelegate: AnyObject {
    func allOpenTabsForTabGroupingManager(_ tabGroupingManager: TabGroupingManager) -> [BrowserTab]
}

class TabGroupingManager {

    typealias PageID = ClusteringManager.PageID
    typealias PageGroupDictionary = [PageID: TabGroup]
    private let myQueue = DispatchQueue(label: "tabGroupingManagerQueue")
    var colorGenerator = TabGroupingColorGenerator()
    weak var delegate: TabGroupingManagerDelegate?
    var hasPagesGroup: Bool {
        !builtPagesGroups.isEmpty
    }
    private var storeManager: TabGroupingStoreManager? {
        BeamData.shared.tabGroupingDBManager
    }

    /// Page associated to a manual group because Clustering found some grouping with pages inside a manual group.
    private var temporaryInManualPageGroups = PageGroupDictionary()
    /// Groups suggested purely by Clustering
    private var clusteringPageGroups = PageGroupDictionary()

    /// Final built page groups, combining the manually grouped pages and the clustering suggestions.
    @Published private(set) var builtPagesGroups = PageGroupDictionary()

    /// The UI might want to temporarily force a tab in or out a group, independently of its page.
    /// Either for temporary UI states (opening a new tab in group). Or while we're waiting for Clustering to update.
    private(set) var forcedTabsGroup = [BrowserTab.TabID: TabForcedGroup]()

    func existingGroup(forGroupID: TabGroup.GroupID) -> TabGroup? {
        builtPagesGroups.values.first { $0.id == forGroupID }
    }

    /// Manually assign a tab to a group, or prevent from being assigned to that group.
    func moveTab(_ tab: BrowserTab, inGroup: TabGroup?, outOfGroup: TabGroup? = nil) {
        forcedTabsGroup[tab.id, default: .init()].update(inGroup: inGroup, outOfGroup: outOfGroup)
        if inGroup == nil && outOfGroup == nil {
            forcedTabsGroup.removeValue(forKey: tab.id)
        }
        let pageId = tab.pageId
        if let inGroup = inGroup {
            builtPagesGroups[pageId] = inGroup
        }
        if outOfGroup != nil {
            if temporaryInManualPageGroups[pageId] == outOfGroup {
                temporaryInManualPageGroups.removeValue(forKey: pageId)
            }
            if clusteringPageGroups[pageId] == outOfGroup {
                clusteringPageGroups.removeValue(forKey: pageId)
            }
            if builtPagesGroups[pageId] == outOfGroup {
                builtPagesGroups.removeValue(forKey: pageId)
            }
        }
    }

    func createNewGroup() -> TabGroup {
        TabGroup(pageIds: [], color: colorGenerator.generateNewColor())
    }

    private func createNewEmptyGroupForClustering() -> TabGroup {
        Logger.shared.logInfo("New TabGroup created by clustering", category: .tabGrouping)
        return createNewGroup()
    }
}

// MARK: - Group Editing
extension TabGroupingManager {

    func copyForSharing(_ group: TabGroup) -> TabGroup {
        let newGroup = group.copy(locked: true, discardPages: false)
        groupDidChangeMetadata(newGroup)
        return newGroup
    }

    func renameGroup(_ group: TabGroup, title: String) {
        group.changeTitle(title)
        Logger.shared.logInfo("Tab Group renamed to '\(title)' (\(group.id))", category: .tabGrouping)
        groupDidChangeMetadata(group)
    }

    func changeGroupColor(_ group: TabGroup, color: TabGroupingColor) {
        group.changeColor(color)
        groupDidChangeMetadata(group)
    }

    func pageWasMovedInsideSameGroup(pageId: ClusteringManager.PageID, group: TabGroup) {
        groupDidChangeContent(group, fromUser: true)
    }

    func pageWasMoved(pageId: ClusteringManager.PageID, fromGroup: TabGroup?, toGroup: TabGroup?) {
        Logger.shared.logInfo("Page(\(pageId)) moved from group '\(fromGroup?.title ?? "")' to group '\(toGroup?.title ?? "")'", category: .tabGrouping)
        if let fromGroup = fromGroup {
            fromGroup.updatePageIds(fromGroup.pageIds.filter { $0 != pageId })
            groupDidChangeContent(fromGroup, fromUser: true)
        }
        if let toGroup = toGroup {
            toGroup.updatePageIds(toGroup.pageIds + [pageId])
            groupDidChangeContent(toGroup, fromUser: true)
        }
    }

    func ungroup(_ group: TabGroup) {
        Logger.shared.logInfo("Ungrouping Gab Group '\(group.title ?? "\(group.id)")'", category: .tabGrouping)
        group.updatePageIds([])
        groupDidChangeContent(group, fromUser: true)
    }

    func toggleCollapse(_ group: TabGroup) {
        group.toggleCollapsed()
        Logger.shared.logInfo("Tab Group '\(group.title ?? "\(group.id)")' \(group.collapsed ? "collapsed" : "expanded")", category: .tabGrouping)
    }

    private func allOpenTabs() -> [BrowserTab] {
        delegate?.allOpenTabsForTabGroupingManager(self) ?? []
    }

    private func groupDidChangeMetadata(_ group: TabGroup) {
        Task { @MainActor in
            await storeManager?.groupDidUpdate(group, origin: .userGroupMetadataChange, openTabs: allOpenTabs())
        }
    }

    private func groupDidChangeContent(_ group: TabGroup, fromUser: Bool) {
        Task { @MainActor in
            await storeManager?.groupDidUpdate(group, origin: fromUser ? .userGroupReordering : .clustering, openTabs: allOpenTabs())
        }
    }

    private func groupsWereUpdatedByClustering(_ groups: Set<TabGroup>) {
        groups.forEach { group in
            Task { @MainActor in
                await storeManager?.groupDidUpdate(group, origin: .clustering, openTabs: allOpenTabs())
            }
        }
    }
}

// MARK: - Clustering Handling
extension TabGroupingManager {

    func removeClosedPages(urlGroups: [[ClusteringManager.PageID]], openPages: [ClusteringManager.PageID?]) -> [[ClusteringManager.PageID]] {
        var newUrlGroups = [[ClusteringManager.PageID]]()
        for group in urlGroups where group.count > 0 {
            newUrlGroups.append(group.filter { Set(openPages).contains($0) })
        }
        return newUrlGroups
    }

    func removeSingles(urlGroups: [[ClusteringManager.PageID]], openTabs: [BrowserTab]) -> [[ClusteringManager.PageID]] {
        var urlGroups = urlGroups
        if urlGroups.count == 1 {
            // we have one group with all tabs in it, let's split into groups of 1 page
            urlGroups = urlGroups.first?.map { [$0] } ?? []
        }
        return urlGroups.filter { group in
            guard group.count > 1 || openTabs.filter({ $0.pageId == group.first }).count > 1 else { return false }
            return true
        }
    }

    @MainActor
    func updateAutomaticClustering(urlGroups: [[ClusteringManager.PageID]], openPages: [ClusteringManager.PageID?]? = nil) async {
        let openTabs = allOpenTabs()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            myQueue.async {
                var groupsOfOpen = urlGroups
                if let openPages = openPages {
                    groupsOfOpen = self.removeClosedPages(urlGroups: urlGroups, openPages: openPages)
                    groupsOfOpen = self.removeSingles(urlGroups: groupsOfOpen, openTabs: openTabs)
                    // TODO: Consider coloring lone tabs that are in a group with a note
                    // TODO: Consider merging groups based on active sources as well
                    // TODO: Consider using similarity scores with notes/active-sources to split groups (similar to sources that are not to be suggested despite being in the correct group)
                }
                self.buildTabGroups(receivingClusters: groupsOfOpen, allOpenTabs: openTabs)
                continuation.resume()
            }
        }
    }

    private func buildManualPageGroups(allOpenTabs: [BrowserTab]) -> (inGroups: PageGroupDictionary, outOfGroups: PageGroupDictionary) {
        var manualPageGroups = [PageID: TabGroup]()
        var forcedOutOfGroup = [PageID: TabGroup]()
        forcedTabsGroup.forEach { (tabId, value) in
            guard let tab = allOpenTabs.first(where: { $0.id == tabId }) else { return }
            if let inGroup = value.inGroup {
                manualPageGroups[tab.pageId] = inGroup
            }
            if let outGroup = value.outOfGroup {
                forcedOutOfGroup[tab.pageId] = outGroup
            }
        }
        return (manualPageGroups, forcedOutOfGroup)
    }

    /// Transforms the pageIDs groups into TabClusteringGroup associated to each pageID.
    /// It will try to maintain the same group properties for each update.
    private func buildTabGroups(receivingClusters clusters: [[ClusteringManager.PageID]], allOpenTabs: [BrowserTab]) {
        temporaryInManualPageGroups.removeAll()
        let (manualPageGroups, forcedOutOfGroups) = buildManualPageGroups(allOpenTabs: allOpenTabs)
        let clusteringPageGroups = clusteringPageGroups
        var newClusteringPageGroups = [PageID: TabGroup]()

        for cluster in clusters {

            // First, find existing group that have some of these pages
            var manualGroupsFound = Set<TabGroup>()
            var suggestedGroupsFound = Set<TabGroup>()
            cluster.forEach { pageId in
                if let manualGroup = manualPageGroups[pageId] {
                    manualGroupsFound.insert(manualGroup)
                }
                if let suggestedGroup = clusteringPageGroups[pageId] {
                    suggestedGroupsFound.insert(suggestedGroup)
                }
            }

            let finalGroup: TabGroup
            var unassignedPages: [PageID] = cluster

            if !manualGroupsFound.isEmpty {
                // if some pages are manually assigned to a group,
                // let's assign the other pages of this cluster to that group too.
                var manualGroupsForThesePages = [TabGroup: [PageID]]()
                var manualGroupWithMostMatches: (group: TabGroup, pagesCount: Int)?
                var leftovers = [PageID]()
                cluster.forEach { pageId in
                    if let manualGroup = manualPageGroups[pageId] {
                        // pages manually assigned already
                        manualGroupsForThesePages[manualGroup, default: []].append(pageId)
                        let count = manualGroupsForThesePages[manualGroup]?.count ?? 0
                        if (manualGroupWithMostMatches?.pagesCount ?? -1) < count {
                            manualGroupWithMostMatches = (manualGroup, count)
                        }
                    } else {
                        // pages suggested by clustering, not manually assigned yet.
                        leftovers.append(pageId)
                    }
                }
                unassignedPages = leftovers
                if let manualGroupWithMostMatches = manualGroupWithMostMatches, manualGroupWithMostMatches.group.canBeUpdatedByClustering {
                    leftovers.forEach { pageId in
                        guard forcedOutOfGroups[pageId] != manualGroupWithMostMatches.group else { return }
                        temporaryInManualPageGroups[pageId] = manualGroupWithMostMatches.group
                    }
                    finalGroup = manualGroupWithMostMatches.group
                } else {
                    // no group? create one for leftovers.
                    finalGroup = createNewEmptyGroupForClustering()
                }

            } else if suggestedGroupsFound.count == 1, let first = suggestedGroupsFound.first {
                // if some pages were already in a suggested group, let's use that one.
                finalGroup = first

            } else if suggestedGroupsFound.count > 1 {
                // but if we found multiple suggested groups,
                // let's take the previous that have the most shared pageIds with this cluster
                var bestGroup: TabGroup?
                var bestCount = 0
                suggestedGroupsFound.forEach { grp in
                    let count = grp.pageIds.filter { cluster.contains($0) }.count
                    if count > bestCount {
                        bestCount = count
                        bestGroup = grp
                    }
                }
                if bestCount > 0, let bestGroup = bestGroup {
                    finalGroup = bestGroup
                } else {
                    finalGroup = createNewEmptyGroupForClustering()
                }
            } else {
                finalGroup = createNewEmptyGroupForClustering()
            }

            unassignedPages.forEach { pageId in
                guard forcedOutOfGroups[pageId] != finalGroup else { return }
                newClusteringPageGroups[pageId] = finalGroup
            }
        }

        let finalGroupAssociation = mergeFinalPageGroupAssociations(manualPageGroups: manualPageGroups, forcedOutOfGroups: forcedOutOfGroups,
                                                                    temporaryInManualPageGroups: temporaryInManualPageGroups,
                                                                    clusteringPageGroups: newClusteringPageGroups)
        self.clusteringPageGroups = newClusteringPageGroups
        self.builtPagesGroups = finalGroupAssociation
        let allGroups = Set(finalGroupAssociation.values)
        DispatchQueue.main.async {
            self.groupsWereUpdatedByClustering(allGroups)
            self.colorGenerator.updateUsedColor(allGroups.compactMap { $0.color })
        }
        Logger.shared.logDebug("TabGroups updated by clustering", category: .tabGrouping)
    }

    private func mergeFinalPageGroupAssociations(manualPageGroups: PageGroupDictionary, forcedOutOfGroups: PageGroupDictionary,
                                                 temporaryInManualPageGroups: PageGroupDictionary, clusteringPageGroups: PageGroupDictionary) -> PageGroupDictionary {
        let finalGroupAssociation = manualPageGroups.merging(temporaryInManualPageGroups, uniquingKeysWith: { a, _ in
            return a
        }).merging(clusteringPageGroups, uniquingKeysWith: { a, _ in
            return a
        })

        let groupsAndTheirPages = finalGroupAssociation.reduce(into: [TabGroup: [PageID]]()) { partialResult, v in
            guard forcedOutOfGroups[v.key] != v.value else { return }
            partialResult[v.value, default: []].append(v.key)
        }
        groupsAndTheirPages.forEach { (group: TabGroup, pages: [PageID]) in
            if group.color == nil {
                group.changeColor(colorGenerator.generateNewColor(), isInitialColor: true)
            }
            group.updatePageIds(pages)
        }
        return finalGroupAssociation
    }

}
