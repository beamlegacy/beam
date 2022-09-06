//
//  TabGroupingFeedbackWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/03/2022.
//

import Foundation

final class TabGroupingFeedbackViewModel: ObservableObject {
    @Published var clusteringManager: ClusteringManager
    @Published var groups: [TabGroup] = []
    private(set) var correctedPages = [ClusteringManager.PageID: TabGroup.GroupID]()
    private(set) var initialAssignations = [ClusteringManager.PageID: TabGroup.GroupID]()

    init(clusteringManager: ClusteringManager) {
        self.clusteringManager = clusteringManager
        prepareData()
    }

    private func prepareData() {
        var groups = [TabGroup]()

        // we copy the existing groups (to be able to change them without consequences)
        let existingBuiltGroups = Set((self.clusteringManager.tabGroupingManager?.builtPagesGroups ?? [:]).values)
        existingBuiltGroups.forEach { tabGroup in
            let copyOfExistingGroup = tabGroup.copy(locked: false, discardPages: false)
            groups.append(copyOfExistingGroup)
            copyOfExistingGroup.pageIds.forEach { pageId in
                initialAssignations[pageId] = copyOfExistingGroup.id
            }
        }

        // we create a new group for each page without group.
        let pages = allOpenedPages()
        let pagesGrouped = groups.flatMap({ $0.pageIds })
        for pageId in pages where !pagesGrouped.contains(pageId) {
            let group = TabGroup(pageIds: [pageId])
            group.changeColor(getNewColor())
            groups.append(group)
        }

        self.groups = groups
    }

    func urlFor(pageId: UUID) -> URL? {
        guard let tree = self.clusteringManager.openBrowsing.allOpenBrowsingTrees.first(where: {$0.browsingTree?.current.link == pageId}),
                let urlStr = tree.browsingTree?.current.url else { return nil }
        return URL(string: urlStr)
    }

    func titleFor(pageId: UUID) -> String? {
        guard let tree = self.clusteringManager.openBrowsing.allOpenBrowsingTrees.first(where: {$0.browsingTree?.current.link == pageId}) else { return nil }
        return tree.browsingTree?.current.title
    }

    // MARK: - Groups reorganization 
    func getNewColor() -> TabGroupingColor {
        clusteringManager.tabGroupingManager?.colorGenerator.generateNewColor() ?? .init()
    }

    func updateCorrectedPages(with pageId: ClusteringManager.PageID, in groupId: UUID) {
        if initialAssignations[pageId] == groupId {
            correctedPages.removeValue(forKey: pageId)
        } else {
            correctedPages.updateValue(groupId, forKey: pageId)
        }
    }

    /// - Returns: `true` if the page was removed from a group
    func remove(pageId: UUID) -> Bool {
        let groupIdx = groups.firstIndex { group in
            return group.pageIds.contains(pageId)
        }
        guard let groupIdx = groupIdx else { return false }
        removePage(pageId, fromGroup: groups[groupIdx])
        removeEmptyGroups()
        return true
    }

    private func removePage(_ pageId: ClusteringManager.PageID, fromGroup group: TabGroup) {
        var newPageIDs = group.pageIds
        newPageIDs.removeAll(where: { $0 == pageId })
        group.updatePageIds(newPageIDs)
    }

    private func removeEmptyGroups() {
        self.groups = groups.filter { !$0.pageIds.isEmpty }
    }

    func allOpenedPages() -> [ClusteringManager.PageID] {
        self.clusteringManager.openBrowsing.allOpenBrowsingPages.compactMap { $0 }
    }

    func buildCorrectedPagesForExport() -> [ClusteringManager.ClusteringFeedbackCorrectedPage] {
        var final = Set<ClusteringManager.ClusteringFeedbackCorrectedPage>()
        let initalGroupIds = Set(initialAssignations.values)
        correctedPages.forEach { (pageId, groupId) in
            let isGroupCreatedDuringFeedback = !initalGroupIds.contains(groupId)
            let newGroup = groups.first(where: { $0.id == groupId })
            let correctedGroupId = !isGroupCreatedDuringFeedback || newGroup?.pageIds.count != 1 ? groupId : nil
            let cfcp = ClusteringManager.ClusteringFeedbackCorrectedPage(pageId: pageId, groupId: correctedGroupId,
                                                                         isGroupCreatedDuringFeedback: correctedGroupId != nil && isGroupCreatedDuringFeedback)
            final.insert(cfcp)

            if isGroupCreatedDuringFeedback, let newGroup = newGroup {
                for pageIdInNewGroup in newGroup.pageIds where pageIdInNewGroup != pageId {
                    let cfcp = ClusteringManager.ClusteringFeedbackCorrectedPage(pageId: pageIdInNewGroup, groupId: groupId,
                                                                                 isGroupCreatedDuringFeedback: isGroupCreatedDuringFeedback)
                    final.insert(cfcp)
                }
            }
        }

        // also send the page that are now alone in their initial group as if they were corrected out of the group
        initialAssignations.forEach { (pageId, groupId) in
            if let group = groups.first(where: { $0.id == groupId }), group.pageIds.count == 1 && group.pageIds.contains(pageId) {
                let cfcp = ClusteringManager.ClusteringFeedbackCorrectedPage(pageId: pageId, groupId: nil,
                                                                             isGroupCreatedDuringFeedback: false)
                final.insert(cfcp)
            }
        }
        return Array(final)
    }
}

class TabGroupingFeedbackWindow: NSWindow, NSWindowDelegate {

    init(contentRect: NSRect, clusteringManager: ClusteringManager) {
        super.init(contentRect: contentRect,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        title = "Tab Grouping Feedback"
        let tabGroupingContentView = TabGroupingFeedbackContentView(viewModel: TabGroupingFeedbackViewModel(clusteringManager: clusteringManager))

        contentView = BeamHostingView(rootView: tabGroupingContentView)
        isMovableByWindowBackground = false
        delegate = self
        isReleasedWhenClosed = false
    }

    override func close() {
        guard let tabGroupingManager = BeamData.shared.clusteringManager.tabGroupingManager else { return }
        let usedColors = Array(Set(tabGroupingManager.builtPagesGroups.compactMap { $0.value.color }))
        tabGroupingManager.colorGenerator.updateUsedColor(usedColors)
        AppDelegate.main.tabGroupingFeedbackWindow = nil
        super.close()
    }
}
