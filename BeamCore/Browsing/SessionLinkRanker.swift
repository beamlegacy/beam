//
//  SessionUrlRanker.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 01/06/2021.
//

import Foundation

public class SessionLinkRanker {
    var browsingTrees: [BrowsingTree] = [BrowsingTree]()

    public func addTree(tree: BrowsingTree) {
        browsingTrees.append(tree)
    }

    func scoreFor(link: UUID) -> Score? {
        let scores = browsingTrees.compactMap { $0.scores[link] }
        if scores.count == 0 { return nil }
        return scores.reduce(Score(), { $0.aggregate($1) })
    }
    private func scoredLinks(links: [UUID]) -> [(UUID, Score)] {
        let scoredLinks = zip(links, links.map { scoreFor(link: $0) })
        return scoredLinks.compactMap { (link, score) -> (UUID, Score)? in
            guard let score = score else { return nil }
            return (link, score)
        }
    }
    public func clusteringSorted(links: [UUID], date: Date = BeamDate.now) -> [UUID] {
        //leftmost elements are to be displayed first
        let existingScoredLinks = scoredLinks(links: links)
        return existingScoredLinks.sorted(by: { $0.1.clusteringScore(date: date) > $1.1.clusteringScore(date: date) }).map { $0.0 }
    }

    public func clusteringRemovalSorted(links: [UUID], date: Date = BeamDate.now) -> [UUID] {
        //leftmost returned elements are to be removed first
        let existingScoredLinks = scoredLinks(links: links)
        return existingScoredLinks.sorted(by: { $0.1.clusteringRemovalLessThan($1.1, date: date) }).map { $0.0 }
    }

    public init() {}
}
