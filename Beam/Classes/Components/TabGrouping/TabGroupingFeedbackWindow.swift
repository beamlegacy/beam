//
//  TabGroupingFeedbackWindow.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 21/03/2022.
//

import Foundation

class TabGroupingFeedbackViewModel: ObservableObject {
    @Published var clusteringManager: ClusteringManager
    @Published var groups: [TabClusteringGroup] = []
    var correctedPages: [ClusteringManager.PageID: UUID] = [ : ]

    init(clusteringManager: ClusteringManager) {
        self.clusteringManager = clusteringManager
        prepareData()
    }

    private func prepareData() {
        let pagesGroups = self.clusteringManager.tabGroupingUpdater.builtPagesGroups.values
        for pagesGroup in pagesGroups {
            if !self.groups.contains(pagesGroup),
                let pageGroupCopy = pagesGroup.copy() {
                self.groups.append(pageGroupCopy)
            }
        }

        let pages = self.clusteringManager.openBrowsing.allOpenBrowsingPages
        let pagesGrouped = self.groups.flatMap({ $0.pageIDs })
        for page in pages where !pagesGrouped.contains(where: { $0 == page }) {
            guard let pageId = page, let hueTint = getNewhueTint() else { continue }
            self.groups.append(TabClusteringGroup(pageIDs: [pageId], hueTint: hueTint))
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
    func getNewhueTint() -> Double? {
        let newHue = clusteringManager.tabGroupingUpdater.hueGenerator.generate()
        clusteringManager.tabGroupingUpdater.hueGenerator.taken.append(newHue)
        return newHue
    }

    func updateCorrectedPages(with pageId: ClusteringManager.PageID, in groupId: UUID) {
        correctedPages.updateValue(groupId, forKey: pageId)
    }

    func remove(tabId: UUID) -> Int? {
        var tabIdx: Int = 0
        let groupIdx = groups.firstIndex { group in
            if let idx = group.pageIDs.firstIndex(where: { $0 == tabId}) {
                tabIdx = idx
                return true
            }
            return false
        }
        guard let groupIdx = groupIdx else { return nil }
        groups[groupIdx].pageIDs.remove(at: tabIdx)

        return groupIdx
    }

    func remove(group: Int) {
        if groups[group].pageIDs.isEmpty {
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
    }

    deinit {
        AppDelegate.main.data.clusteringManager.tabGroupingUpdater.hueGenerator.taken = Array(Set(AppDelegate.main.data.clusteringManager.tabGroupingUpdater.builtPagesGroups.map { $0.value.hueTint }))
        AppDelegate.main.tabGroupingFeedbackWindow = nil
    }
}
