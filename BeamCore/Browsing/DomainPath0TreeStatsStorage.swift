//
//  TreeDomainPath0StatsStorage.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 04/03/2022.
//

import Foundation

public struct ScoredDomainPath0: Decodable {
    public let domainPath0: String
    public let score: Float

    public init(domainPath0: String, score: Float) {
        self.domainPath0 = domainPath0
        self.score = score
    }
}

public protocol DomainPath0TreeStatsStorageProtocol {
    func update(treeId: UUID, url: String, readTime: Double, date: Date)
    func update(treeId: UUID, lifeTime: Double)
    func cleanUp(olderThan days: Int, maxRows: Int)
    func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float,
                                       dayRange: Int, maxRows: Int) -> [ScoredDomainPath0]
    var domainPath0MinReadDay: Date? { get }
}
