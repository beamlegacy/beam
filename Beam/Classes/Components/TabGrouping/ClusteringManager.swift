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
    @Published var clusteredPagesId: [[UInt64]] = [[]] {
        didSet {
            transformToClusteredPages()
        }
    }
    @Published var clusteredTabs: [[TabInformation?]] = [[]]
    @Published var isClustering: Bool = false
    private var tabsInfo: [TabInformation] = []
    private var cluster: Cluster

    init() {
        self.cluster = Cluster()
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
}
