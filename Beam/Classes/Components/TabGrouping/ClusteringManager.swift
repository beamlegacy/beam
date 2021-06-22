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
    @Published var clusteredTabs: [[TabInformation?]] = [[]]
    @Published var isClustering: Bool = false
    @Published var selectedTabGroupingCandidate = 1
    @Published var weightNavigation = 0.5
    @Published var weightText = 0.5
    @Published var weightEntities = 0.5
    private var tabsInfo: [TabInformation] = []
    private var cluster: Cluster
    private var scope = Set<AnyCancellable>()

    init() {
        self.cluster = Cluster()
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

    func addPage(id: UInt64, parentId: UInt64?, value: TabInformation) {
        let page = Page(id: id, parentId: parentId, title: value.document.title, content: value.cleanedTextContentForClustering)
        tabsInfo.append(value)
        isClustering = true
        var ranking: [UInt64]?
        // if self.sendRanking {
        //     ranking = self.clusteredPagesId.reduce([], +)
        // }
        cluster.add(page, ranking: ranking) { result in
            switch result {
            case .failure(let error):
                self.isClustering = false
                Logger.shared.logError("Error while adding page to cluster for \(page): \(error)", category: .clustering)
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

    func change(candidate: Int, weightNavigation: Double?, weightText: Double?, weightEntities: Double?) {
        isClustering = true
        cluster.changeCandidate(to: candidate, with: weightNavigation, with: weightText, with: weightEntities) { result in
            switch result {
            case .failure(let error):
                self.isClustering = false
                Logger.shared.logError("Error while changing candidate to cluster for: \(error)", category: .clustering)
            case .success(let result):
                DispatchQueue.main.async {
                    self.isClustering = false
                    self.clusteredPagesId = result.0
                    self.sendRanking = result.1
                    self.logForClustering(result: result.0, changeCandidate: true)
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
            Logger.shared.logDebug("Result provided by ClusteringFramework from changing to candidate \(self.selectedTabGroupingCandidate) with Nav \(self.weightNavigation), Text \(self.weightText), Entities \(self.weightEntities) for result: \(result)", category: .clustering)
        } else {
            Logger.shared.logDebug("Result provided by ClusteringFramework for adding a page with candidate\(self.selectedTabGroupingCandidate): \(result)", category: .clustering)
        }

    }
}
