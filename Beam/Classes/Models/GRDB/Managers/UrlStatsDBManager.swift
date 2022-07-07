//
//  UrlStatsDBManager.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 08/06/2022.
//

import Foundation
import GRDB
import BeamCore

class UrlStatsDBManager: GRDBHandler, BeamManager {
    weak public private(set) var holder: BeamManagerOwner?
    static var id = UUID()
    static var name = "UrlStatsDBManager"

    required init(holder: BeamManagerOwner?, store: GRDBStore) throws {
            self.holder = holder
            try super.init(store: store)
        }

    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override var tableNames: [String] { ["longTermUrlScore", "DailyUrlScore"] }

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
    }

    // MARK: - LongTermUrlScore
    func getLongTermUrlScore(urlId: UUID) -> LongTermUrlScore? {
        return try? self.read { db in try LongTermUrlScore.fetchOne(db, id: urlId) }
    }

    func updateLongTermUrlScore(urlId: UUID, changes: @escaping (LongTermUrlScore) -> Void ) {
        do {
            try self.write { db in
                let score = (try? LongTermUrlScore.fetchOne(db, id: urlId)) ?? LongTermUrlScore(urlId: urlId)
                changes(score)
                try score.save(db)
            }
        } catch {
            Logger.shared.logError("Couldn't update url long term score for \(urlId)", category: .database)
        }
    }

    func getManyLongTermUrlScore(urlIds: [UUID]) -> [LongTermUrlScore] {
        return (try? self.read { db in try LongTermUrlScore.fetchAll(db, ids: urlIds) }) ?? []
    }

    func save(scores: [LongTermUrlScore]) throws {
        try self.write { db in
            for score in scores {
                try score.save(db)
            }
        }
    }
    func clearLongTermScores() throws {
        _ = try self.write { db in
            try LongTermUrlScore.deleteAll(db)
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

    //day in format "YYYY-MM-DD"
    func clearDailyUrlScores(toDay day: String? = nil) throws {
        try self.write { db in
            if let day = day {
                let timeCond = DailyURLScore.Columns.localDay <= day
                try DailyURLScore.filter(timeCond).deleteAll(db)
            } else {
                try DailyURLScore.deleteAll(db)
            }
        }
    }
}

extension BeamManagerOwner {
    var urlStatsDBManager: UrlStatsDBManager? {
        try? manager(UrlStatsDBManager.self)
    }
}

extension BeamData {
    var urlStatsDBManager: UrlStatsDBManager? {
        currentAccount?.urlStatsDBManager
    }
}
