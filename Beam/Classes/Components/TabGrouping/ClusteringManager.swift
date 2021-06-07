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
    @Published var clusteredTabs: [[TabInformation?]] = [[]]
    @Published var isClustering: Bool = false
    @Published var selectedTabGroupingCandidate = 1
    private var tabsInfo: [TabInformation] = []
    private var cluster: Cluster
    private var scope = Set<AnyCancellable>()

    init() {
        self.cluster = Cluster()

        $selectedTabGroupingCandidate.sink { value in
            self.change(candidate: value)
        }.store(in: &scope)
    }

    func addPage(id: UInt64, parentId: UInt64?, value: TabInformation) {
        let page = Page(id: id, parentId: parentId, title: value.document.title, content: value.textContent)
        tabsInfo.append(value)
        isClustering = true
        cluster.add(page) { result in
            switch result {
            case .failure(let error):
                self.isClustering.toggle()
                Logger.shared.logError("Error while adding page to cluster for \(page): \(error)", category: .clustering)
            case .success(let result):
                DispatchQueue.main.async {
                    self.isClustering.toggle()
                    self.clusteredPagesId = result
                    self.logForClustering(result: result, changeCandidate: false)
                }
            }
        }
    }

    func change(candidate: Int) {
        if tabsInfo.isEmpty || isClustering { return }
        isClustering = true
        cluster.changeCandidate(to: candidate) { result in
            switch result {
            case .failure(let error):
                self.isClustering.toggle()
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                DispatchQueue.main.async {
                    self.isClustering.toggle()
                    self.clusteredPagesId = result
                    self.logForClustering(result: result, changeCandidate: true)
                }
            }
        }
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
            Logger.shared.logDebug("Result provided by ClusteringFramework from changing to candidate \(self.selectedTabGroupingCandidate): \(result)", category: .clustering)
        } else {
            Logger.shared.logDebug("Result provided by ClusteringFramework for adding a page with candidate\(self.selectedTabGroupingCandidate): \(result)", category: .clustering)
        }

    }
}
