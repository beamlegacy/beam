//
//  LongTermUrlScore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 09/07/2021.
//

import GRDB
import BeamCore

extension LongTermUrlScore: Identifiable {
    public var id: UUID { urlId }
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
    let db: GRDBDatabase
    static let shared = LongTermUrlScoreStore()
    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    func apply(to urlId: UUID, changes: (LongTermUrlScore) -> Void) {
        db.updateLongTermUrlScore(urlId: urlId, changes: changes)
    }

    func getMany(urlIds: [UUID]) -> [LongTermUrlScore] {
        return db.getManyLongTermUrlScore(urlIds: urlIds)
    }
}
