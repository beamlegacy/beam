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
    let providedDb: UrlStatsDBManager?
    var db: UrlStatsDBManager? {
        let currentDb = providedDb ?? BeamData.shared.urlStatsDBManager
        if currentDb == nil {
            Logger.shared.logError("LongTermUrlScoreStore has no UrlStatsDBManager available", category: .database)
        }
        return currentDb
    }

    let daysToKeep: Int
    init(db providedDb: UrlStatsDBManager? = nil, daysToKeep: Int = 2) {
        self.providedDb = providedDb
        self.daysToKeep = daysToKeep
    }

    func apply(to urlId: UUID, changes: @escaping (DailyURLScore) -> Void) {
        guard let db = db, let localDay = BeamDate.now.localDayString() else { return }
        db.updateDailyUrlScore(urlId: urlId, day: localDay, changes: changes)
    }

    func cleanup() {
        guard let db = db else { return }
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
        guard let db = db else { return [UUID: DailyURLScore]() }
        let now = BeamDate.now
        let cal = Calendar(identifier: .iso8601)
        guard let day = cal.date(byAdding: DateComponents(day: -daysAgo), to: now)?.localDayString() else { return [:] }
        return db.getDailyUrlScores(day: day)
    }
    func getDailyRepeatingUrlsWithoutFragment(between offset0: Int, and offset1: Int, minRepeat: Int) -> Set<String> {
        guard let db = db else { return Set<String>() }
        let now = BeamDate.now
        let cal = Calendar(identifier: .iso8601)
        guard let leftBound = cal.date(byAdding: DateComponents(day: -offset0), to: now)?.localDayString(),
              let rightBound = cal.date(byAdding: DateComponents(day: -offset1), to: now)?.localDayString() else { return Set<String>() }
        do {
            return try db.getDailyRepeatingUrlsWithoutFragment(between: leftBound, and: rightBound, minRepeat: minRepeat)
        } catch {
            Logger.shared.logError("Couldn't get daily repeating urls: \(error)", category: .database)
            return Set<String>()
        }
    }
    func getUrlWithoutFragmentDistinctVisitDayCount(between offset0: Int, and offset1: Int) -> [String: Int] {
        guard let db = db else { return [String: Int]() }
        let now = BeamDate.now
        let cal = Calendar(identifier: .iso8601)
        guard let leftBound = cal.date(byAdding: DateComponents(day: -offset0), to: now)?.localDayString(),
              let rightBound = cal.date(byAdding: DateComponents(day: -offset1), to: now)?.localDayString() else { return [String: Int]() }
        do {
            return try db.getUrlWithoutFragmentDistinctVisitDayCount(between: leftBound, and: rightBound)
        } catch {
            Logger.shared.logError("Couldn't get distinct visit day count: \(error)", category: .database)
            return [String: Int]()
        }
    }
}
