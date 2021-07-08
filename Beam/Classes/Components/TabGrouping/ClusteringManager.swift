//
//  ClusteringManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 31/05/2021.
//

import Foundation
import BeamCore
import Combine
import Clustering
import Fakery

class ClusteringManager: ObservableObject {
    var clusteredPagesId: [[UInt64]] = [[]] {
        didSet {
            transformToClusteredPages()
        }
    }
    var sendRanking = false
    var ranker: SessionLinkRanker
    @Published var clusteredTabs: [[TabInformation?]] = [[]]
    @Published var isClustering: Bool = false
    @Published var selectedTabGroupingCandidate = 1
    @Published var weightNavigation = 0.5
    @Published var weightText = 0.5
    @Published var weightEntities = 0.5
    private var tabsInfo: [TabInformation] = []
    private var cluster: Cluster
    private var scope = Set<AnyCancellable>()

    init(ranker: SessionLinkRanker) {
        self.cluster = Cluster()
        self.ranker = ranker
        setupObservers()
    }

    private func setupObservers() {
        $selectedTabGroupingCandidate.sink { value in
            self.change(candidate: value,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightNavigation.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: value,
                        weightText: self.weightText,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightText.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: value,
                        weightEntities: self.weightEntities)
        }.store(in: &scope)

        $weightEntities.sink { value in
            self.change(candidate: self.selectedTabGroupingCandidate,
                        weightNavigation: self.weightNavigation,
                        weightText: self.weightText,
                        weightEntities: value)
        }.store(in: &scope)
    }

    func getIdAndParent(tabToIndex: TabInformation) -> (UInt64?, UInt64?) {
        var id = tabToIndex.currentTabTree?.current.link
        var parentId = tabToIndex.parentBrowsingNode?.link
        var parentTimeStamp = Date.distantPast
        if let parent = tabToIndex.parentBrowsingNode,
           let lastEventType = parent.events.last?.type {
            if let lastEventTime = parent.events.last?.date {
                parentTimeStamp = lastEventTime
            }
            if lastEventType == .searchBarNavigation || lastEventType == .exitForward || lastEventType == .exitBackward {
                parentId = nil
            }
        }
        if let children = tabToIndex.currentTabTree?.current.children {
            for child in children {
                if let lastEventType = child.events.last?.type,
                   let lastEventTime = child.events.last?.date,
                   lastEventType == .exitBackward,
                   lastEventTime > parentTimeStamp {
                    parentTimeStamp = lastEventTime
                    parentId = nil
                    // TODO: Reconsider the relation implied by the back button
                    // when it is 100% reliable. (probably should stay the same)
                }
            }
        }
        // By definition, when opening a link in a new tab the link either
        // has no children or their events are farther in the past
        if let current = tabToIndex.currentTabTree?.current.events.last?.type,
           current == .openLinkInNewTab,
           let tabTree = tabToIndex.tabTree?.current.link {
            parentId = id
            id = tabTree
        }
        if let previousTabTree = tabToIndex.previousTabTree,
           let type = previousTabTree.current.events.last?.type,
           type == .openLinkInNewTab {
            parentId = previousTabTree.current.link
        }
        return (id, parentId)
    }

    func addPage(id: UInt64, parentId: UInt64?, value: TabInformation? = nil, newContent: String? = nil) {
        var pageToAdd: Page?
        if let value = value {
            pageToAdd = Page(id: id, parentId: parentId, title: value.document.title, content: value.cleanedTextContentForClustering)
            tabsInfo.append(value)
        } else if let newContent = newContent {
            pageToAdd = Page(id: id, parentId: nil, title: nil, content: newContent)
            // TODO: Shold we bother changing the content in tabsInfo?
        }
        isClustering = true
        var ranking: [UInt64]?
        if self.sendRanking {
            ranking = self.ranker.clusteringRemovalSorted(links: self.clusteredPagesId.reduce([], +))
        }
        var replaceContent = false
        if let pageToAdd = pageToAdd {
            if let _ = newContent {
                replaceContent = true
            }
            cluster.add(pageToAdd, ranking: ranking, replaceContent: replaceContent) { result in
                switch result {
                case .failure(let error):
                    self.isClustering = false
                    Logger.shared.logError("Error while adding page to cluster for \(pageToAdd): \(error)", category: .clustering)
                case .success(let result):
                    DispatchQueue.main.async {
                        self.isClustering = false
                        self.clusteredPagesId = result.0
                        self.sendRanking = result.1
                        self.logForClustering(result: result.0, changeCandidate: false)
                    }
                }
            }
        }
    }

    func change(candidate: Int, weightNavigation: Double, weightText: Double, weightEntities: Double) {
        isClustering = true
        cluster.changeCandidate(to: candidate, with: weightNavigation, with: weightText, with: weightEntities) { result in
            switch result {
            case .failure(let error):
                self.isClustering = false
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                DispatchQueue.main.async {
                    self.isClustering = false
                    self.clusteredPagesId = self.reorganizeGroups(clusters: result.0)
                    self.sendRanking = result.1
                    self.logForClustering(result: result.0, changeCandidate: true)
                }
            }
        }
    }

    private func reorganizeGroups(clusters: [[UInt64]]) -> [[UInt64]] {
        var clusters = clusters
        for cluster in clusters.enumerated() {
            clusters[cluster.offset] = self.ranker.clusteringSorted(links: cluster.element)
        }
        return clusters
    }

    private func transformToClusteredPages() {
        let clusteredTabs = self.clusteredPagesId.compactMap({ cluster in
            return cluster.map { id in
                return tabsInfo.first(where: { $0.document.id == id })
            }
        })
        DispatchQueue.main.async {
            self.clusteredTabs = clusteredTabs
        }
    }

    private func logForClustering(result: [[UInt64]], changeCandidate: Bool) {
        if changeCandidate {
            Logger.shared.logDebug("Result provided by ClusteringFramework from changing to candidate \(self.selectedTabGroupingCandidate) with Nav \(self.weightNavigation), Text \(self.weightText), Entities \(self.weightEntities) for result: \(result)", category: .clustering)
        } else {
            Logger.shared.logDebug("Result provided by ClusteringFramework for adding a page with candidate\(self.selectedTabGroupingCandidate): \(result)", category: .clustering)
        }

    }
}
