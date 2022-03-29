import Foundation

class TabClusteringGroup: Identifiable, Equatable, Codable {
    static func == (lhs: TabClusteringGroup, rhs: TabClusteringGroup) -> Bool {
        lhs.id == rhs.id
    }

    var id = UUID()
    /// List of Clustering Link ids
    var pageIDs: [ClusteringManager.PageID]
    /// hue value between 0 and 1
    var hueTint: Double

    init(pageIDs: [ClusteringManager.PageID], hueTint: Double) {
        self.pageIDs = pageIDs
        self.hueTint = hueTint
    }

    func copy() -> TabClusteringGroup? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }

        let decoder = JSONDecoder()
        return try? decoder.decode(TabClusteringGroup.self, from: data)
    }
}

class TabGroupingUpdater {
    private let myQueue = DispatchQueue(label: "tabGroupingUpdaterQueue")
    var hueGenerator = DistributedRandomGenerator(range: 0.0..<1.0)

    @Published private(set) var builtPagesGroups = [ClusteringManager.PageID: TabClusteringGroup]()

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

    func update(urlGroups: [[ClusteringManager.PageID]], openPages: [ClusteringManager.PageID?]? = nil) {
        myQueue.async {
            var groupsOfOpen = urlGroups
            if let openPages = openPages {
                groupsOfOpen = self.removeClosedPages(urlGroups: urlGroups, openPages: openPages)
                groupsOfOpen = self.removeSingles(urlGroups: groupsOfOpen)
                // TODO: Consider coloring lone tabs that are in a group with a note
                // TODO: Consider merging groups based on active sources as well
                // TODO: Consider using similarity scores with notes/active-sources to split groups (similar to sources that are not to be suggested despite being in the correct group)
            }
            DispatchQueue.main.async { [unowned self] in
                self.buildTabClusteringGroups(urlGroups: groupsOfOpen)
            }
        }
    }

    /// Transforms the pageIDs groups into TabClusteringGroup associated to each pageID.
    /// It will try to maintain the same group properties for each update.
    private func buildTabClusteringGroups(urlGroups: [[ClusteringManager.PageID]]) {
        let previousGroups = self.builtPagesGroups
        var pagesGroups = [ClusteringManager.PageID: TabClusteringGroup]()
        urlGroups.forEach({ group in
            let groupHue = hueGenerator.generate()
            hueGenerator.taken.append(groupHue)

            let pageGroup = TabClusteringGroup(pageIDs: [], hueTint: groupHue)
            var previousGroupsFound = [TabClusteringGroup]()
            group.forEach { pageId in
                pagesGroups[pageId] = pageGroup
                pageGroup.pageIDs.append(pageId)
                if let previousGroup = previousGroups[pageId], !previousGroupsFound.contains(where: { $0 == previousGroup }) {
                    previousGroupsFound.append(previousGroup)
                }
            }
            if previousGroupsFound.count == 1, let first = previousGroupsFound.first {
                pageGroup.hueTint = first.hueTint
            } else if previousGroupsFound.count > 1 {
                // take the previous that have the most shared tabsId with the new group
                var bestGroup: TabClusteringGroup?
                var bestCount = 0
                previousGroupsFound.forEach { grp in
                    let count = grp.pageIDs.filter { pageGroup.pageIDs.contains($0) }.count
                    if count > bestCount {
                        bestCount = count
                        bestGroup = grp
                    }
                }
                if bestCount > 0, let bestGroup = bestGroup {
                    pageGroup.hueTint = bestGroup.hueTint
                }
            }
        })
        self.builtPagesGroups = pagesGroups
        hueGenerator.taken = Array(Set(self.builtPagesGroups.map { $0.value.hueTint }))
    }
}
