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
    let db: GRDBDatabase
    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }
    func update(treeId: UUID, url: String, readTime: Double,  date: Date) {
        guard let url = URL(string: url),
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
        do {
            try db.updateBrowsingTreeStats(treeId: treeId) { record in record.lifeTime = lifeTime }
        } catch {
            Logger.shared.logError("Couldn't update domain tree stats for tree: \(treeId) - \(error)", category: .database)
        }
    }
    func cleanUp(olderThan days: Int, maxRows: Int) {
        do {
            try db.cleanBrowsingTreeStats(olderThan: days, maxRows: maxRows)
            try db.cleanDomainPath0TreeStat(olderThan: days, maxRows: maxRows)
            try db.cleanDomainPath0ReadingDay(olderThan: days, maxRows: maxRows)
        } catch {
            Logger.shared.logError("Couldn't cleanup domain tree stats - \(error)", category: .database)
        }
    }

    var domainPath0MinReadDay: Date? {
        db.domainPath0MinReadDay
    }

    func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float,
                                       dayRange: Int, maxRows: Int) -> [ScoredDomainPath0] {
        do {
            return try db.getPinTabSuggestionCandidates(minDayCount: minDayCount, minTabReadingTimeShare: minTabReadingTimeShare, minAverageTabLifetime: minAverageTabLifetime, dayRange: dayRange, maxRows: maxRows)
        } catch {
            Logger.shared.logError("Couldn't fetch tab pin candidates - \(error)", category: .database)
            return []
        }
    }
}
