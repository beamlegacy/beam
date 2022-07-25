//
//  LongTermUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import Foundation

private let HALF_LIFE = Float(30.0 * 86400) // 30 days

public class LongTermUrlScore: Codable, UrlScoreProtocol {
    public enum CodingKeys: String, CodingKey {
        case urlId
        case visitCount
        case readingTimeToLastEvent
        case textSelections
        case scrollRatioX
        case scrollRatioY
        case textAmount
        case area
        case lastCreationDate
        case navigationCountSinceLastSearch
    }

    public let urlId: UUID
    public var visitCount: Int = 0
    public var readingTimeToLastEvent: CFTimeInterval = 0
    public var textSelections: Int = 0
    public var scrollRatioX: Float = 0
    public var scrollRatioY: Float = 0
    public var textAmount: Int = 0
    public var area: Float = 0
    public var lastCreationDate: Date?
    public var navigationCountSinceLastSearch: Int?

    public init(urlId: UUID) {
        self.urlId = urlId
    }

    public func score(date: Date = BeamDate.now) -> Float {
        guard let lastCreationDate = lastCreationDate else { return 0 }
        let timeSinceLastCreation = Float(date.timeIntervalSince(lastCreationDate))
        return min(scrollRatioY, 1) // temporary before scroll ratio fix
            + log(1 + Float(readingTimeToLastEvent))
            + log(1 + Float(textAmount))
            + log(1 + Float(textSelections))
            + logTimeDecay(duration: timeSinceLastCreation, halfLife: HALF_LIFE)
    }
    public func update(treeScore: Score) {
        visitCount += treeScore.visitCount
        readingTimeToLastEvent += treeScore.readingTimeToLastEvent
        textSelections += treeScore.textSelections
        scrollRatioX = max(scrollRatioX, treeScore.scrollRatioX)
        scrollRatioY = max(scrollRatioY, treeScore.scrollRatioY)
        textAmount = max(textAmount, treeScore.textAmount)
        area = max(area, treeScore.area)
        lastCreationDate = nilMax(lastCreationDate, treeScore.lastCreationDate)
        navigationCountSinceLastSearch = nilMin(navigationCountSinceLastSearch, treeScore.navigationCountSinceLastSearch)
    }
}

public protocol LongTermUrlScoreStoreProtocol {
    func apply(to urlId: UUID, changes: @escaping (LongTermUrlScore) -> Void)
    func getMany(urlIds: [UUID]) -> [UUID: LongTermUrlScore]
    func save(scores: [LongTermUrlScore])
}
