//
//  DailyUrlScore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 28/03/2022.
//

import Foundation
import GRDB
import BeamCore

extension DailyURLScore: FetchableRecord {}
extension DailyURLScore: PersistableRecord {}
extension DailyURLScore: TableRecord {
    enum Columns: String, ColumnExpression {
            case id, createdAt, updatedAt, urlId, localDay
        }
}
extension DailyURLScore: Identifiable {}

class GRDBDailyUrlScoreStore: DailyUrlScoreStoreProtocol {
    let db: GRDBDatabase
    let daysToKeep: Int
    init(db: GRDBDatabase = GRDBDatabase.shared, daysToKeep: Int = 2) {
        self.db = db
        self.daysToKeep = daysToKeep
    }

    func apply(to urlId: UUID, changes: (DailyURLScore) -> Void) {
        guard let localDay = BeamDate.now.localDayString() else { return }
        db.updateDailyUrlScore(urlId: urlId, day: localDay, changes: changes)
    }

    func cleanup() {
        do {
            let now = BeamDate.now
            let bound = Calendar(identifier: .iso8601).date(byAdding: DateComponents(day: -daysToKeep), to: now)?.localDayString()
            try db.clearDailyUrlScores(toDay: bound ?? "0000-00-00")
        } catch {
            Logger.shared.logError("Couldn't clearn daily url scores: \(error)", category: .database)
        }
    }

    func getHighScoredUrlIds(daysAgo: Int = 1, topN: Int = 5) -> [DailyURLScore] {
        let scores = getScores(daysAgo: daysAgo).values
        let filtered = scores.filter { score in
            !(score.isPinned || score.urlId == Link.missing.id)
        }
        let sorted = filtered.sorted { (leftScore, rightScore) in leftScore.score > rightScore.score }
        return Array(sorted.prefix(topN))
    }
    func getScores(daysAgo: Int = 1) -> [UUID: DailyURLScore] {
        let now = BeamDate.now
        let cal = Calendar(identifier: .iso8601)
        guard let day = cal.date(byAdding: DateComponents(day: -daysAgo), to: now)?.localDayString() else { return [:] }
        return db.getDailyUrlScores(day: day)
    }
}
