//
//  LongTermUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import Foundation

public class LongTermUrlScore: Codable {
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

    public let urlId: UInt64
    public var visitCount: Int = 0
    public var readingTimeToLastEvent: CFTimeInterval = 0
    public var textSelections: Int = 0
    public var scrollRatioX: Float = 0
    public var scrollRatioY: Float = 0
    public var textAmount: Int = 0
    public var area: Float = 0
    public var lastCreationDate: Date?

    public init(urlId: UInt64) {
        self.urlId = urlId
    }
}

public protocol LongTermUrlScoreStoreProtocol {
    func apply(to urlId: UInt64, changes: (LongTermUrlScore) -> Void)
}
