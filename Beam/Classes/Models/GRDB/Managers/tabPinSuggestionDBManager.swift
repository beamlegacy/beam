//
//  tabPinSuggestionDBManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 08/06/2022.
//

import Foundation
import GRDB
import BeamCore

class TabPinSuggestionDBManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    static var id = UUID()

    static var name = "TabPinSuggestionDBManager"

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.holder = holder
        try super.init(store: store)
    }

    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override var tableNames: [String] { ["BrowsingTreeStats", "DomainPath0TreeStats", "DomainPath0ReadingDay", "TabPinSuggestion"] }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("createPinTabSuggestiongTables") { db in
            try db.create(table: "BrowsingTreeStats", ifNotExists: true) { t in
                t.column("treeId", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("readingTime", .double)
                t.column("lifeTime", .double)
            }

            try db.create(table: "DomainPath0TreeStats", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("domainPath0", .text).notNull()
                t.column("treeId", .text).notNull()
                t.column("readingTime", .double)
            }
            try db.create(index: "DomainPath0TreeStatsIndex", on: "domainPath0TreeStats", columns: ["treeId", "domainPath0"], unique: true)

            try db.create(table: "DomainPath0ReadingDay", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("domainPath0", .text).indexed()
                t.column("readingDay", .date).indexed()
                t.uniqueKey(["domainPath0", "readingDay"], onConflict: .ignore)
            }

            try db.create(table: "TabPinSuggestion", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("domainPath0", .text).indexed()
                t.uniqueKey(["domainPath0"], onConflict: .ignore)
            }
        }
    }

    // MARK: - DomainPath0ReadingDay
    func addDomainPath0ReadingDay(domainPath0: String, date: Date) throws {
        guard let truncatedDate = date.utcDayTruncated else { return }
        let record = DomainPath0ReadingDay(domainPath0: domainPath0, readingDay: truncatedDate)
        try self.write { db in
            try record.insert(db)
        }
    }
    var domainPath0MinReadDay: Date? {
        do {
            return try self.read { db in
                try Date.fetchOne(db, DomainPath0ReadingDay.select(min(DomainPath0ReadingDay.Columns.readingDay)))
            }
        } catch {
            Logger.shared.logError("Couldn't fetch min domainPath0 min read day", category: .database)
            return nil
        }
    }

    func cleanDomainPath0ReadingDay(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = DomainPath0ReadingDay.Columns.readingDay <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = DomainPath0ReadingDay
            .select(DomainPath0ReadingDay.Columns.id)
            .order(DomainPath0ReadingDay.Columns.readingDay.desc)
            .limit(maxRows)
        try _ = self.write { db in
            try DomainPath0ReadingDay
                .filter(timeCond || !rankSubQuery.contains(DomainPath0ReadingDay.Columns.id))
                .deleteAll(db)
        }
    }
    func countDomainPath0ReadingDay(domainPath0: String) throws -> Int {
        try self.read { db in
            try DomainPath0ReadingDay.filter(DomainPath0ReadingDay.Columns.domainPath0 == domainPath0).fetchCount(db)
        }
    }
    // MARK: - DomainPath0TreeStat
    func getDomainPath0TreeStat(domainPath0: String, treeId: UUID) throws -> DomainPath0TreeStats? {
        try self.read { db in
            try DomainPath0TreeStats
                .filter(DomainPath0TreeStats.Columns.domainPath0 == domainPath0)
                .filter(DomainPath0TreeStats.Columns.treeId == treeId)
                .fetchOne(db)
        }
    }

    func updateDomainPath0TreeStat(domainPath0: String, treeId: UUID, readingTime: Double) throws {
        var existingRecord = try getDomainPath0TreeStat(domainPath0: domainPath0, treeId: treeId)
        existingRecord?.updatedAt = BeamDate.now
        var recordToSave = existingRecord ?? DomainPath0TreeStats(treeId: treeId, domainPath0: domainPath0)
        recordToSave.readingTime += readingTime
        try self.write { db in
            try recordToSave.save(db)
        }
    }

    func cleanDomainPath0TreeStat(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = DomainPath0TreeStats.Columns.updatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = DomainPath0TreeStats.select(DomainPath0TreeStats.Columns.id)
            .order(DomainPath0TreeStats.Columns.updatedAt.desc)
            .limit(maxRows)
        try _ = self.write { db in
            try DomainPath0TreeStats
                .filter(timeCond || !rankSubQuery.contains(DomainPath0TreeStats.Columns.id))
                .deleteAll(db)
        }
    }
    // MARK: - BrowsingTreeStats
    func getBrowsingTreeStats(treeId: UUID) throws -> BrowsingTreeStats? {
        try self.read { db in
            try BrowsingTreeStats.fetchOne(db, id: treeId)
        }
    }
    func updateBrowsingTreeStats(treeId: UUID, changes: @escaping (BrowsingTreeStats) -> Void ) throws {
        try self.write { db in
            let existingStats = try BrowsingTreeStats.fetchOne(db, id: treeId)
            existingStats?.updatedAt = BeamDate.now
            let stats = existingStats ?? BrowsingTreeStats(treeId: treeId)
            changes(stats)
            try stats.save(db)
        }
    }
    func cleanBrowsingTreeStats(olderThan days: Int = 30, maxRows: Int = 50 * 1000) throws {
        let now = BeamDate.now
        let timeCond = BrowsingTreeStats.Columns.updatedAt <= now - Double(days * 24 * 60 * 60)
        let rankSubQuery = BrowsingTreeStats.select(BrowsingTreeStats.Columns.treeId)
            .order(BrowsingTreeStats.Columns.updatedAt.desc)
            .limit(maxRows)

        try _ = self.write { db in
            try BrowsingTreeStats
                .filter(timeCond || !rankSubQuery.contains(BrowsingTreeStats.Columns.treeId))
                .deleteAll(db)
        }
    }
    // MARK: - TabPinSuggestions
    func addTabPinSuggestion(domainPath0: String) throws {
        let suggestion = TabPinSuggestion(domainPath0: domainPath0)
        try self.write { db in
            try suggestion.insert(db)
        }
    }
    var tabPinSuggestionCount: Int {
        (try? self.read { db in
            try TabPinSuggestion.fetchCount(db)
        }) ?? 0
    }
    func alreadyPinTabSuggested(domainPath0: String) throws -> Bool {
        try self.read { db in
            try TabPinSuggestion.filter(TabPinSuggestion.Columns.domainPath0 == domainPath0).fetchCount(db) > 0
        }
    }
    func cleanTabPinSuggestions() throws {
        try _ = self.write { db in
            try TabPinSuggestion.deleteAll(db)
        }
    }

    func getPinTabSuggestionCandidates(minDayCount: Int, minTabReadingTimeShare: Float, minAverageTabLifetime: Float,
                                       dayRange: Int, maxRows: Int) throws -> [ScoredDomainPath0] {
        let rightTimeBound = BeamDate.now
        let leftTimeBound = rightTimeBound - Double(dayRange * 24 * 60 * 60)
        let query: SQLRequest<ScoredDomainPath0> = SQLRequest("""
            WITH distinctReadDays AS (
              SELECT
                domainPath0,
                COUNT(1) readDayCount
              FROM DomainPath0ReadingDay d
              WHERE readingDay BETWEEN \(leftTimeBound) AND \(rightTimeBound)
              GROUP BY domainPath0
              HAVING readDayCount >= \(minDayCount)
            ),

            domainTreeStats AS (
              SELECT
                domainPath0,
                SUM(dt.readingTime) as readingTime,
                SUM(t.readingTime) as treeReadingTime,
                AVG(t.lifeTime) as treeLifetime
              FROM domainPath0TreeStats dt
              JOIN browsingTreeStats t ON dt.treeId = t.treeId
              WHERE dt.updatedAt BETWEEN \(leftTimeBound) AND \(rightTimeBound)
              GROUP BY dt.domainPath0
              HAVING
                SUM(t.readingTime) > 0
                AND SUM(dt.readingTime) / SUM(t.readingTime) >= \(minTabReadingTimeShare)
                AND AVG(t.lifeTime) >= \(minAverageTabLifetime)
            )

            SELECT d.domainPath0, (d.readDayCOunt * dt.readingTime / dt.treeReadingTime * dt.treeLifeTime) AS score
            FROM distinctReadDays d
            JOIN domainTreeStats dt ON d.domainPath0 = dt.domainPath0
            ORDER BY (d.readDayCOunt * dt.readingTime / dt.treeReadingTime * dt.treeLifeTime) DESC
            LIMIT \(maxRows)
        """
        )

        return try self.read { db in
            try ScoredDomainPath0.fetchAll(db, query)
        }
    }
}

extension BeamManagerOwner {
    var tabPinSuggestionDBManager: TabPinSuggestionDBManager? {
        try? manager(TabPinSuggestionDBManager.self)
    }
}

extension BeamData {
    var tabPinSuggestionDBManager: TabPinSuggestionDBManager? {
        AppData.shared.currentAccount?.tabPinSuggestionDBManager
    }
}
