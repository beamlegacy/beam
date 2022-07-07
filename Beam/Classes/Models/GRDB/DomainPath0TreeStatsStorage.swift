//
//  DomainPath0TreeStatsStorage.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 04/03/2022.
//

import Foundation
import BeamCore
import GRDB

extension ScoredDomainPath0: FetchableRecord {}

class DomainPath0TreeStatsStorage: DomainPath0TreeStatsStorageProtocol {
    let providedDb: TabPinSuggestionDBManager?
    var db: TabPinSuggestionDBManager? {
        let currentDb = providedDb ?? BeamData.shared.tabPinSuggestionDBManager
        if currentDb == nil {
            Logger.shared.logError("DomainPath0TreeStatsStorage has no TabPinSuggestionDBManager available", category: .database)
        }
        return currentDb
    }

    init(db providedDb: TabPinSuggestionDBManager? = nil) {
        self.providedDb = providedDb
    }
    func update(treeId: UUID, url: String, readTime: Double, date: Date) {
        guard let db = db,
              let url = URL(string: url),
              !url.isSearchEngineResultPage,
              let domainPath0 = url.domainPath0?.absoluteString else { return }
        do {
            try db.updateDomainPath0TreeStat(domainPath0: domainPath0, treeId: treeId, readingTime: readTime)
            try db.updateBrowsingTreeStats(treeId: treeId) { record in record.readingTime += readTime }
            try db.addDomainPath0ReadingDay(domainPath0: domainPath0, date: date)
        } catch {
            Logger.shared.logError("Couldn't update domain tree stats for tree: \(treeId) url: \(url) - \(error)", category: .database)
        }
    }
    func update(treeId: UUID, lifeTime: Double) {
        guard let db = db else { return }
        do {
            try db.updateBrowsingTreeStats(treeId: treeId) { record in record.lifeTime = lifeTime }
        } catch {
            Logger.shared.logError("Couldn't update domain tree stats for tree: \(treeId) - \(error)", category: .database)
        }
    }
    func cleanUp(olderThan days: Int, maxRows: Int) {
        guard let db = db else { return }
        do {
            try db.cleanBrowsingTreeStats(olderThan: days, maxRows: maxRows)
            try db.cleanDomainPath0TreeStat(olderThan: days, maxRows: maxRows)
            try db.cleanDomainPath0ReadingDay(olderThan: days, maxRows: maxRows)
        } catch {
            Logger.shared.logError("Couldn't cleanup domain tree stats - \(error)", category: .database)
        }
    }

    var domainPath0MinReadDay: Date? {
        db?.domainPath0MinReadDay
    }

    func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float,
                                       dayRange: Int, maxRows: Int) -> [ScoredDomainPath0] {
        guard let db = db else { return [ScoredDomainPath0]() }
        do {
            return try db.getPinTabSuggestionCandidates(minDayCount: minDayCount, minTabReadingTimeShare: minTabReadingTimeShare, minAverageTabLifetime: minAverageTabLifetime, dayRange: dayRange, maxRows: maxRows)
        } catch {
            Logger.shared.logError("Couldn't fetch tab pin candidates - \(error)", category: .database)
            return []
        }
    }
}
