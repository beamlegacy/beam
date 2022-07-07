//
//  TabGroupingFeedbackWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/03/2022.
//

import Foundation

class TabGroupingFeedbackViewModel: ObservableObject {
    @Published var clusteringManager: ClusteringManager
    @Published var groups: [TabGroup] = []
    var correctedPages: [ClusteringManager.PageID: UUID] = [ : ]

    init(clusteringManager: ClusteringManager) {
        self.clusteringManager = clusteringManager
        prepareData()
    }

    private func prepareData() {
        let pagesGroups = (self.clusteringManager.tabGroupingManager?.builtPagesGroups ?? [:]).values
        for pagesGroup in pagesGroups where !self.groups.contains(pagesGroup) {
            guard let pageGroupCopy = pagesGroup.copy() else { continue }
            self.groups.append(pageGroupCopy)
        }

        let pages = self.clusteringManager.openBrowsing.allOpenBrowsingPages
        let pagesGrouped = self.groups.flatMap({ $0.pageIds })
        for page in pages where !pagesGrouped.contains(where: { $0 == page }) {
            guard let pageId = page,
                  !self.groups.flatMap({ $0.pageIds }).contains(pageId) else { continue }

            let group = TabGroup(pageIds: [pageId])
            group.changeColor(getNewColor())
            self.groups.append(group)
        }
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
        correctedPages.updateValue(groupId, forKey: pageId)
    }

    func remove(tabId: UUID) -> Int? {
        var tabIdx: Int = 0
        let groupIdx = groups.firstIndex { group in
            if let idx = group.pageIds.firstIndex(where: { $0 == tabId}) {
                tabIdx = idx
                return true
            }
            return false
        }
        guard let groupIdx = groupIdx else { return nil }
        var newPageIDs = groups[groupIdx].pageIds
        newPageIDs.remove(at: tabIdx)
        groups[groupIdx].updatePageIds(newPageIDs)

        return groupIdx
    }

    func remove(group: Int) {
        if groups[group].pageIds.isEmpty {
            groups.remove(at: group)
        }
        objectWillChange.send()
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
