//
//  BrowsingTree+Flatten.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 13/01/2022.
//

import Foundation

extension BrowsingNode {
    //parent and children relationship erased
    var serializable: BrowsingNode {
        BrowsingNode(
            id: id,
            link: link,
            events: events,
            legacy: legacy,
            isLinkActivation: isLinkActivation
        )
    }
}

public struct FlatennedBrowsingTree: Codable {

    let currentIndex: Int
    let scores: [UUID: Score]
    let origin: BrowsingTreeOrigin
    var nodes: [BrowsingNode]
    var parentIndexes: [Int?]

    func node(index: Int) -> BrowsingNode? {
        guard index < nodes.count else { return nil }
        return nodes[index]
    }
    public var root: BrowsingNode? {
        return node(index: 0)
    }
    public var current: BrowsingNode? {
        return node(index: currentIndex)
    }
    public var copy: FlatennedBrowsingTree {
        FlatennedBrowsingTree(
            currentIndex: currentIndex,
            scores: scores,
            origin: origin,
            nodes: nodes.map { $0.serializable },
            parentIndexes: parentIndexes)
    }
}
