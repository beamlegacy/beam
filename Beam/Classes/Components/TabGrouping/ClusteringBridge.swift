//
//  ClusteringBridge.swift
//  Beam
//
//  Created by Ludovic Ollagnier on 21/07/2022.
//

import Clustering
import BeamCore

enum ClusteringType {
    /// v1
    case legacy
    /// v2
    case smart

    var isSupported: Bool {
        switch self {
        case .legacy: return true
        // we're disabling the support for clustering v2.
        case .smart: return false
        }
    }

    static var current: ClusteringType {
        return .legacy
    }

    func buildBridge(selectedTabGroupingCandidate: Int,
                     weightNavigation: Double, weightText: Double, weightEntities: Double) -> ClusteringBridge {
        switch self {
        case .legacy:
            return LegacyClusteringBridge(selectedTabGroupingCandidate: selectedTabGroupingCandidate,
                                          weightNavigation: weightNavigation, weightText: weightText, weightEntities: weightEntities)
        case .smart:
            fatalError("Smart Clustering is not supported anymore")
        }
    }

    var versionRepresentation: Int {
        switch self {
        case .legacy: return 1
        case .smart: return 2
        }
    }

    var shouldRemovePageBeforeAddingNewOne: Bool {
        switch self {
        case .legacy: return false
        case .smart: return true
        }
    }

    var shouldUpdateContentWithPointAndShoot: Bool {
        switch self {
        case .legacy: return true
        case .smart: return false
        }
    }

    /// With Legacy Clustering, if no cluster were detected,
    /// the clustering would produce a single group with all pages in it.
    var producesSingleGroupWithAllPages: Bool {
        switch self {
        case .legacy: return true
        case .smart: return false
        }
    }
}

struct ClusteringResultValue {
    var groups: [[UUID]]
    var legacyFlag: LegacyClustering.Flag?
}

/// Protocol wrapper to switch the Clustering implementation actually used behind
protocol ClusteringBridge {
    var type: ClusteringType { get }
    var selectedTabGroupingCandidate: Int { get set }
    var weightNavigation: Double { get set }
    var weightText: Double { get set }
    var weightEntities: Double { get set }
    var threshold: Float? { get }

    init(selectedTabGroupingCandidate: Int, weightNavigation: Double, weightText: Double, weightEntities: Double)

    typealias CompletionResult = Result<ClusteringResultValue, Error>

    func add(textualItem: TextualItem, ranking: [UUID]?, replaceContent: Bool, completion: @escaping (CompletionResult) -> Void)
    func removeTextualItem(textualItemUUID: UUID, textualItemTabId: UUID, completion: @escaping (CompletionResult) -> Void)
    func changeCandidate(to candidate: Int?,
                         withWeightNavigation weightNavigation: Double?, weightText: Double?, weightEntities: Double?,
                         completion: @escaping (CompletionResult) -> Void)
    func getExportInformationForId(id: UUID) -> Clustering.InformationForId
}

extension ClusteringBridge {

    /// convenient method with default parameter for`replaceContent`
    func add(textualItem: TextualItem, ranking: [UUID]?, completion: @escaping (CompletionResult) -> Void) {
        add(textualItem: textualItem, ranking: ranking, replaceContent: false, completion: completion)
    }
}

enum ClusteringBridgeError: Error {
    case notImplemented
}

// MARK: - Legacy Clustering
/// Wrapper for Clustering.LegacyClustering
final class LegacyClusteringBridge: ClusteringBridge {

    var type: ClusteringType { .legacy }
    var selectedTabGroupingCandidate: Int
    var weightNavigation: Double
    var weightText: Double
    var weightEntities: Double
    var threshold: Float? { nil }

    private lazy var legacy = LegacyClustering(candidate: selectedTabGroupingCandidate,
                                               weightNavigation: weightNavigation,
                                               weightText: weightText,
                                               weightEntities: weightEntities,
                                               noteContentThreshold: 100)

    init(selectedTabGroupingCandidate: Int, weightNavigation: Double, weightText: Double, weightEntities: Double) {
        self.selectedTabGroupingCandidate = selectedTabGroupingCandidate
        self.weightNavigation = weightNavigation
        self.weightText = weightText
        self.weightEntities = weightEntities
    }

    private typealias LegacyClusteringResult = Result<(pageGroups: [[UUID]], noteGroups: [[UUID]],
                                                       flag: LegacyClustering.Flag, similarities: [UUID: [UUID: Float]]), Error>
    private func convertLegacyClusteringResult(_ result: LegacyClusteringResult) -> CompletionResult {
        switch result {
        case .failure(let error): return .failure(error)
        case .success(let v):
            let groups = zip(v.pageGroups, v.noteGroups).map { $0.0 + $0.1 }
            return .success(.init(groups: groups, legacyFlag: v.flag))
        }

    }
    func add(textualItem: TextualItem, ranking: [UUID]?, replaceContent: Bool, completion: @escaping (CompletionResult) -> Void) {
        legacy.add(textualItem: textualItem, ranking: ranking, activeSources: nil, replaceContent: replaceContent) { [weak self] in
            guard let self = self else { return }
            completion(self.convertLegacyClusteringResult($0))
        }
    }

    func removeTextualItem(textualItemUUID: UUID, textualItemTabId: UUID,
                           completion: @escaping (CompletionResult) -> Void) {
        legacy.removeTextualItem(textualItemUUID: textualItemUUID)
        completion(.success(.init(groups: [])))
    }

    func changeCandidate(to candidate: Int?, withWeightNavigation weightNavigation: Double?, weightText: Double?, weightEntities: Double?, completion: @escaping (CompletionResult) -> Void) {
        legacy.changeCandidate(to: candidate, with: weightNavigation, with: weightText, with: weightEntities, activeSources: nil) { [weak self] in
            guard let self = self else { return }
            completion(self.convertLegacyClusteringResult($0))
        }
    }

    public func getExportInformationForId(id: UUID) -> Clustering.InformationForId {
        legacy.getExportInformationForId(id: id)
    }
}
