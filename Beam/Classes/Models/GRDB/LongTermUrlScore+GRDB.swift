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
    let providedDb: UrlStatsDBManager?
    var db: UrlStatsDBManager? {
        let currentDb = providedDb ?? BeamData.shared.urlStatsDBManager
        if currentDb == nil {
            Logger.shared.logError("LongTermUrlScoreStore has no UrlStatsDBManager available", category: .database)
        }
        return currentDb
    }

    static let shared = LongTermUrlScoreStore()
    init(db providedDb: UrlStatsDBManager? = nil) {
        self.providedDb = providedDb
    }

    func apply(to urlId: UUID, changes: @escaping (LongTermUrlScore) -> Void) {
        guard let db = db else { return }
        db.updateLongTermUrlScore(urlId: urlId, changes: changes)
    }

    func getMany(urlIds: [UUID]) -> [UUID: LongTermUrlScore] {
        guard let db = db else { return [UUID: LongTermUrlScore]() }
        let scores = db.getManyLongTermUrlScore(urlIds: urlIds)
        return Dictionary(uniqueKeysWithValues: scores.map { ($0.urlId, $0) })
    }
    func save(scores: [LongTermUrlScore]) {
        guard let db = db else { return }
        do {
            try db.save(scores: scores)
        } catch {
            Logger.shared.logError("Couldn't save long term url scores: \(error)", category: .database)
        }
    }
}
