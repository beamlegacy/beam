//
//  DailyUrlScore.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 28/03/2022.
//

import Foundation

public class DailyURLScore: Codable, UrlScoreProtocol {
    public var id = UUID()
    public var createdAt = BeamDate.now
    public var updatedAt = BeamDate.now
    public var urlId: UUID
    public var localDay: String
    public var visitCount: Int = 0
    public var readingTimeToLastEvent: CFTimeInterval = 0
    public var textSelections: Int = 0
    public var scrollRatioX: Float = 0
    public var scrollRatioY: Float = 0
    public var textAmount: Int = 0
    public var area: Float = 0

    public init(urlId: UUID, localDay: String) {
        self.urlId = urlId
        self.localDay = localDay
    }

    public var score: Float {
        return scrollRatioY
            + log(1 + Float(readingTimeToLastEvent))
            + log(1 + Float(textAmount))
            + log(1 + Float(textSelections))
    }
}

public protocol DailyUrlScoreStoreProtocol {
    func apply(to urlId: UUID, changes: (DailyURLScore) -> Void)
}
