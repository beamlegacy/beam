//
//  UrlStatsDBManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 08/06/2022.
//

import Foundation
import GRDB
import BeamCore

private struct UrlDistinctVisitDayCount: Decodable, FetchableRecord {
    let urlWithoutFragment: String
    let distinctDayCount: Int
}

class UrlStatsDBManager: GRDBHandler, BeamManager {
    weak public private(set) var owner: BeamManagerOwner?
    static var id = UUID()
    static var name = "UrlStatsDBManager"

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
            self.owner = holder
            try super.init(store: store)
        }

    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override var tableNames: [String] { ["DailyUrlScore"] }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {
        migrator.registerMigration("createUrlStatsTables") { db in
            try db.create(table: "longTermUrlScore", ifNotExists: true) { t in
                t.column("urlId", .text).primaryKey()
                t.column("visitCount", .integer).notNull()
                t.column("readingTimeToLastEvent", .double).notNull()
                t.column("textSelections", .integer).notNull()
                t.column("scrollRatioX", .double).notNull()
                t.column("scrollRatioY", .double).notNull()
                t.column("textAmount", .integer).notNull()
                t.column("area", .double).notNull()
                t.column("lastCreationDate", .datetime)
                t.column("navigationCountSinceLastSearch", .integer)
            }

            try db.create(table: "DailyUrlScore", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().indexed().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("urlId", .blob).indexed().notNull()
                t.column("localDay", .text).indexed().notNull()
                t.column("visitCount", .integer).notNull()
                t.column("readingTimeToLastEvent", .double).notNull()
                t.column("textSelections", .integer).notNull()
                t.column("scrollRatioX", .double).notNull()
                t.column("scrollRatioY", .double).notNull()
                t.column("textAmount", .integer).notNull()
                t.column("area", .double).notNull()
                t.column("isPinned", .boolean).defaults(to: false)
                t.column("navigationCountSinceLastSearch", .integer)
                t.uniqueKey(["urlId", "localDay"])
            }
        }
        migrator.registerMigration("dropLongTermUrlScoreTable") { db in
            try db.drop(table: "longTermUrlScore")
        }
    }

    // MARK: - DailyUrlScore
    //day in format "YYYY-MM-DD"
    func updateDailyUrlScore(urlId: UUID, day: String, changes: @escaping (DailyURLScore) -> Void ) {
        do {
            try self.write { db in
                let fetched = try? DailyURLScore
                    .filter(DailyURLScore.Columns.urlId == urlId)
                    .filter(DailyURLScore.Columns.localDay == day)
                    .fetchOne(db)
                let score = fetched ?? DailyURLScore(urlId: urlId, localDay: day)
                changes(score)
                score.updatedAt = BeamDate.now
                try score.save(db)
            }
        } catch {
            Logger.shared.logError("Couldn't update url daily score for \(urlId) at \(day)", category: .database)
        }
    }

    //day in format "YYYY-MM-DD"
    func getDailyUrlScores(day: String) -> [UUID: DailyURLScore] {
        do {
            return try self.read { db in
                let cursor = try DailyURLScore
                        .filter(DailyURLScore.Columns.localDay == day)
                        .fetchCursor(db)
                        .map { ($0.urlId, $0) }
                return try Dictionary(uniqueKeysWithValues: cursor)
            }
        } catch {
            Logger.shared.logError("Couldn't fetch daily url scores at \(day): \(error)", category: .database)
            return [:]
        }
    }
    func getAggregatedDailyUrlScore(leftBound: String, rightBound: String) -> [UUID: AggregatedURLScore] {
        let query: SQLRequest<Row> = SQLRequest("""
            SELECT
                urlId,
                SUM(visitCount) AS visitCount,
                SUM(readingTimeToLastEvent) AS readingTimeToLastEvent,
                SUM(textSelections) AS textSelections,
                MAX(scrollRatioX) AS scrollRatioX,
                MAX(scrollRatioY) AS scrollRatioY,
                MAX(textAmount) AS textAmount,
                MAX(area) AS area,
                MAX(isPinned) AS isPinned,
                MIN(navigationCountSinceLastSearch) AS navigationCountSinceLastSearch
            FROM DailyUrlScore
            WHERE localDay BETWEEN \(leftBound) AND \(rightBound)
            GROUP BY urlId
            """
        )
        do {
            let cursor = try self.read { db in
                return try AggregatedURLScore.fetchAll(db, query)
                    .compactMap { record -> (UUID, AggregatedURLScore)? in
                            guard let urlId = record.urlId else { return nil }
                            return (urlId, record)
                        }
            }
            return Dictionary(uniqueKeysWithValues: cursor)
        } catch {
            Logger.shared.logError("Couldn't aggregate daily url scores between \(leftBound) and \(rightBound): \(error)", category: .database)
            return [:]
        }
    }

    //day in format "YYYY-MM-DD"
    func clearDailyUrlScores(toDay: String? = nil, afterDay: String? = nil) throws {
        try self.write { db in
            if let toDay = toDay {
                let timeCond = DailyURLScore.Columns.localDay <= toDay
                try DailyURLScore.filter(timeCond).deleteAll(db)
            } else if let afterDay = afterDay {
                let timeCond = DailyURLScore.Columns.localDay >= afterDay
                try DailyURLScore.filter(timeCond).deleteAll(db)
            } else {
                try DailyURLScore.deleteAll(db)
            }
        }
    }

    func getDailyRepeatingUrlsWithoutFragment(between leftBound: String, and rightBound: String, minRepeat: Int) throws -> Set<String> {
            let query: SQLRequest<String> = SQLRequest("""
                SELECT
                CASE
                    WHEN INSTR(l.url, '#') > 0 THEN SUBSTR(l.url, 0, INSTR(l.url, '#'))
                    ELSE l.url
                END AS url_without_fragment
                FROM Link AS l
                JOIN DailyUrlScore AS s ON l.id = s.urlId
                WHERE
                    true
                    AND s.localDay BETWEEN \(leftBound) AND \(rightBound)
                    AND s.visitCount >= 1
                GROUP BY 1
                HAVING COUNT(DISTINCT s.localDay) >= \(minRepeat)
                """
                )
            return try self.read { db in
                try String.fetchSet(db, query)
        }
    }
    func getUrlWithoutFragmentDistinctVisitDayCount(between leftBound: String, and rightBound: String) throws -> [String: Int] {
        let query: SQLRequest<Row> = SQLRequest("""
            SELECT
            CASE
                WHEN INSTR(l.url, '#') > 0 THEN SUBSTR(l.url, 0, INSTR(l.url, '#'))
                ELSE l.url
            END AS urlWithoutFragment,
            COUNT(DISTINCT s.localDay) AS distinctDayCount
            FROM Link AS l
            JOIN DailyUrlScore AS s ON l.id = s.urlId
            WHERE
                true
                AND s.localDay BETWEEN \(leftBound) AND \(rightBound)
                AND s.visitCount >= 1
            GROUP BY 1
        """)
        let rows = try self.read { db in
            try UrlDistinctVisitDayCount.fetchAll(db, query)
                .map { ($0.urlWithoutFragment, $0.distinctDayCount)}
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }
}

extension BeamManagerOwner {
    var urlStatsDBManager: UrlStatsDBManager? {
        try? manager(UrlStatsDBManager.self)
    }
}

extension BeamData {
    var urlStatsDBManager: UrlStatsDBManager? {
        AppData.shared.currentAccount?.urlStatsDBManager
    }
}
