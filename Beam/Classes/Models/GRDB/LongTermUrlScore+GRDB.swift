//
//  LongTermUrlScore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import GRDB
import BeamCore

extension LongTermUrlScore: Identifiable {
    public var id: UInt64 { urlId }
}

extension LongTermUrlScore: FetchableRecord {}

extension LongTermUrlScore: PersistableRecord {}

extension LongTermUrlScore: TableRecord {
    enum Columns {
            static let urlId = Column(CodingKeys.urlId)
            static let visitCount = Column(CodingKeys.visitCount)
            static let readingTimeToLastEvent = Column(CodingKeys.readingTimeToLastEvent)
            static let textSelections = Column(CodingKeys.textSelections)
            static let scrollRatioX = Column(CodingKeys.scrollRatioX)
            static let scrollRatioY = Column(CodingKeys.scrollRatioY)
            static let textAmount = Column(CodingKeys.textAmount)
            static let area = Column(CodingKeys.area)
            static let lastCreationDate = Column(CodingKeys.lastCreationDate)
        }
}

class LongTermUrlScoreStore: LongTermUrlScoreStoreProtocol {
    func apply(to urlId: UInt64, changes: (LongTermUrlScore) -> Void) {
        GRDBDatabase.shared.updateLongTermUrlScore(urlId: urlId, changes: changes)
    }
}
