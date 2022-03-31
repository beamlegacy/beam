//
//  LongTermUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import Foundation

private let HALF_LIFE = Float(30.0 * 24.0 * 60.0 * 60.0)

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

    public init(urlId: UUID) {
        self.urlId = urlId
    }

    public func score(date: Date = BeamDate.now) -> Float {
        guard let lastCreationDate = lastCreationDate else { return 0 }
        let timeSinceLastCreation = Float(date.timeIntervalSince(lastCreationDate))
        return scrollRatioY
            + log(1 + Float(readingTimeToLastEvent))
            + log(1 + Float(textAmount))
            + log(1 + Float(textSelections))
            + logTimeDecay(duration: timeSinceLastCreation, halfLife: HALF_LIFE)
    }
}

public protocol LongTermUrlScoreStoreProtocol {
    func apply(to urlId: UUID, changes: (LongTermUrlScore) -> Void)
    func getMany(urlIds: [UUID]) -> [UUID: LongTermUrlScore]
}
