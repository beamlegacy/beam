import Foundation

class TabGroup: Identifiable {

    typealias GroupID = UUID

    private(set) var id = GroupID()
    /// List of Link ids

    private(set) var title: String?
    fileprivate(set) var color: TabGroupingColor?
    fileprivate(set) var pageIds: [ClusteringManager.PageID]
    fileprivate(set) var collapsed = false
    fileprivate(set) var isLocked: Bool = false

    /// Whether or not the group has been interacted with by the user and should therefore be persisted
    private(set) var shouldBePersisted: Bool = false

    init(id: GroupID = GroupID(), pageIds: [ClusteringManager.PageID],
         title: String? = nil, color: TabGroupingColor? = nil, isLocked: Bool = false) {
        self.id = id
        self.pageIds = pageIds
        self.title = title
        self.color = color
        shouldBePersisted = title?.isEmpty == false
    }

    func changeTitle(_ title: String) {
        self.title = title
        shouldBePersisted = !title.isEmpty
    }

    func changeColor(_ color: TabGroupingColor) {
        self.color = color
        shouldBePersisted = true
    }

    func updatePageIds(_ pageIds: [ClusteringManager.PageID]) {
        self.pageIds = pageIds
    }

    func copy() -> TabGroup? {
        let newGroup = TabGroup(pageIds: pageIds)
        newGroup.title = title
        newGroup.color = color
        newGroup.collapsed = collapsed
        newGroup.shouldBePersisted = shouldBePersisted
        return newGroup
    }
}

extension TabGroup: Equatable, Hashable {
    static func == (lhs: TabGroup, rhs: TabGroup) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

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
    private let storeManager = TabGroupingStoreManager.shared

    /// Page associated to a manual group because Clustering found some grouping with pages inside a manual group.
    private var temporaryInManualPageGroups = PageGroupDictionary()
    /// Groups suggested purely by Clustering
    private var clusteringPageGroups = PageGroupDictionary()

    /// Final built page groups, combining the manually grouped pages and the clustering suggestions.
    @Published private(set) var builtPagesGroups = PageGroupDictionary()

    /// The UI might want to temporarily force a tab in or out a group, independently of its page.
    /// Either for temporary UI states (opening a new tab in group). Or while we're waiting for Clustering to update.
    private(set) var forcedTabsGroup = [BrowserTab.TabID: TabForcedGroup]()

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

}

// MARK: - Group Editing
extension TabGroupingManager {
    func renameGroup(_ group: TabGroup, title: String) {
        group.changeTitle(title)
        groupDidChangeMetadata(group)
    }

    func changeGroupColor(_ group: TabGroup, color: TabGroupingColor) {
        group.changeColor(color)
        groupDidChangeMetadata(group)
    }

    func pageWasMoved(pageId: ClusteringManager.PageID, fromGroup: TabGroup?, toGroup: TabGroup?) {
        if let fromGroup = fromGroup {
            fromGroup.pageIds.removeAll { $0 == pageId }
            groupDidChangeContent(fromGroup, fromUser: true)
        }
        if let toGroup = toGroup {
            toGroup.pageIds.append(pageId)
            groupDidChangeContent(toGroup, fromUser: true)
        }
    }

    func ungroup(_ group: TabGroup) {
        group.pageIds.removeAll()
        groupDidChangeContent(group, fromUser: true)
    }

    func toggleCollapse(_ group: TabGroup) {
        group.collapsed.toggle()
    }

    private func allOpenTabs() -> [BrowserTab] {
        delegate?.allOpenTabsForTabGroupingManager(self) ?? []
    }

    private func groupDidChangeMetadata(_ group: TabGroup) {
        storeManager.groupDidUpdate(group, origin: .userGroupMetadataChange, openTabs: allOpenTabs())
    }

    private func groupDidChangeContent(_ group: TabGroup, fromUser: Bool) {
        storeManager.groupDidUpdate(group, origin: fromUser ? .userGroupReordering : .clustering, openTabs: allOpenTabs())
    }

    private func groupsWereUpdatedByClustering(_ groups: Set<TabGroup>) {
        groups.forEach { group in
            storeManager.groupDidUpdate(group, origin: .clustering, openTabs: allOpenTabs())
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

    func removeSingles(urlGroups: [[ClusteringManager.PageID]]) -> [[ClusteringManager.PageID]] {
        var newUrlGroups = [[ClusteringManager.PageID]]()
        for group in urlGroups {
            switch group.count {
            case 0, 1:
                break
            default:
                newUrlGroups.append(group)
            }
        }
        return newUrlGroups
    }

    func updateAutomaticClustering(urlGroups: [[ClusteringManager.PageID]], openPages: [ClusteringManager.PageID?]? = nil) async {
        let openTabs = allOpenTabs()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            myQueue.async {
                var groupsOfOpen = urlGroups
                if let openPages = openPages {
                    groupsOfOpen = self.removeClosedPages(urlGroups: urlGroups, openPages: openPages)
                    groupsOfOpen = self.removeSingles(urlGroups: groupsOfOpen)
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
        // swiftlint:disable:previous cyclomatic_complexity function_body_length

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
                if let manualGroupWithMostMatches = manualGroupWithMostMatches {
                    leftovers.forEach { pageId in
                        guard forcedOutOfGroups[pageId] != manualGroupWithMostMatches.group else { return }
                        temporaryInManualPageGroups[pageId] = manualGroupWithMostMatches.group
                    }
                    unassignedPages.removeAll()
                    finalGroup = manualGroupWithMostMatches.group
                } else {
                    // no group? create one for leftovers.
                    finalGroup = .init(pageIds: [])
                    unassignedPages = leftovers
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
                    finalGroup = .init(pageIds: [])
                }
            } else {
                finalGroup = .init(pageIds: [])
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
                group.color = colorGenerator.generateNewColor()
            }
            group.updatePageIds(pages)
        }
        return finalGroupAssociation
    }

}
