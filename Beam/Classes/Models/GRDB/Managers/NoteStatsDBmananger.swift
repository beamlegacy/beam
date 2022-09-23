//
//  NoteStatsDBmananger.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 01/09/2022.
//

import Foundation
import BeamCore
import GRDB
import UUIDKit

class NoteStatsDBManager: GRDBHandler, BeamManager {
    weak public private(set) var owner: BeamManagerOwner?
    public var database: BeamDatabase? {
        owner as? BeamDatabase
    }

    public static var id = UUID()
    public static var name = "NoteStatsDBManager"

    public override var tableNames: [String] { ["DailyNoteScoreRecord", "NoteLastWordCountChangeDayRecord"] }

    required init(holder: BeamManagerOwner?, objectManager: BeamObjectManager, store: GRDBStore) throws {
        self.owner = holder
        try super.init(store: store)
    }

    /// Creates a `GRDBStore`, and make sure the database schema is ready.
    override required init(store: GRDBStore) throws {
        try super.init(store: store)
    }

    public override func prepareMigration(migrator: inout DatabaseMigrator) throws {

        migrator.registerMigration("createDailyNoteScoreTables") { db in
            try db.create(table: "DailyNoteScoreRecord", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("noteId", .text).notNull()
                t.column("localDay", .text).notNull()
                t.column("minWordCount", .integer)
                t.column("maxWordCount", .integer).notNull().defaults(to: 0)
                t.column("firstWordCount", .integer)
                t.column("lastWordCount", .integer).notNull().defaults(to: 0)
                t.column("addedBidiLinkToCount", .integer).notNull().defaults(to: 0)
                t.column("captureToCount", .integer).notNull().defaults(to: 0)
                t.column("visitCount", .integer).notNull().defaults(to: 0)
            }
            try db.create(index: "DailyNoteScoreLocalDayNoteIdIndex", on: "DailyNoteScoreRecord", columns: ["localDay", "noteId"], unique: true)
            try db.create(table: "NoteLastWordCountChangeDayRecord", ifNotExists: true) { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("noteId", .text).notNull().indexed()
                t.column("lastChangeDay", .text)
                t.column("lastWordCount", .integer).notNull()
            }
            for (day, scores) in KeychainDailyNoteScoreStore.shared.scores {
                for (noteId, score) in scores {
                    let record = DailyNoteScoreRecord(noteId: noteId, localDay: day)
                    record.minWordCount = score.minWordCount
                    record.maxWordCount = score.maxWordCount
                    record.firstWordCount = score.firstWordCount
                    record.lastWordCount = score.lastWordCount
                    record.addedBidiLinkToCount = score.addedBidiLinkToCount
                    record.captureToCount = score.captureToCount
                    record.visitCount = score.visitCount
                    try record.insert(db)
                }
            }
            for (noteId, lastWordCount) in KeychainDailyNoteScoreStore.shared.notesLastWordCountChangeDay {
                let record = NoteLastWordCountChangeDayRecord(noteId: noteId, lastChangeDay: lastWordCount.lastChangeDay, lastWordCount: lastWordCount.lastWordCount)
                try record.insert(db)
            }
            Persistence.NoteScores.lastWordCountChange = nil
            Persistence.NoteScores.daily = nil
        }
    }


    // MARK: - Daily note score
    func applyScoreChange(noteId: UUID, localDay: String, changes: @escaping (DailyNoteScoreRecord) -> Void) throws {
        let fetchCondition = DailyNoteScoreRecord.Columns.localDay == localDay && DailyNoteScoreRecord.Columns.noteId == noteId.uuidString.uppercased()
        _ = try write { db in
            let existing = try DailyNoteScoreRecord.filter(fetchCondition).fetchOne(db)
            existing?.updatedAt = BeamDate.now
            let changed = existing ?? DailyNoteScoreRecord(noteId: noteId, localDay: localDay)
            changes(changed)
            try changed.save(db)
        }
    }

    func clearDailyNoteScores(before day: String? = nil) throws {
        _ = try write { db in
            if let day = day {
                try DailyNoteScoreRecord.filter(DailyNoteScoreRecord.Columns.localDay <= day).deleteAll(db)
            } else {
                try DailyNoteScoreRecord.deleteAll(db)
            }
        }
    }

    func getDailyNoteScore(noteId: UUID, localDay: String) throws -> DailyNoteScoreRecord? {
        return try read { db in
            let fetchCondition = DailyNoteScoreRecord.Columns.localDay == localDay && DailyNoteScoreRecord.Columns.noteId == noteId.uuidString.uppercased()
            return try DailyNoteScoreRecord.filter(fetchCondition).fetchOne(db)
        }
    }

    func getDailyNoteScores(localDay: String) throws -> [UUID: DailyNoteScoreRecord] {
        let records: [DailyNoteScoreRecord] = try read { db in
            let fetchCondition = DailyNoteScoreRecord.Columns.localDay == localDay
            return try DailyNoteScoreRecord.filter(fetchCondition).fetchAll(db)
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.noteId, $0) })
    }

    func getNoteIdsLastChangedAtAndAfter(day: String) throws -> (Set<UUID>, Set<UUID>) {
        let changedAtCond = NoteLastWordCountChangeDayRecord.Columns.lastChangeDay == day
        let changedAfterCond = NoteLastWordCountChangeDayRecord.Columns.lastChangeDay > day
        return try read { db in
            return (
                Set( try NoteLastWordCountChangeDayRecord.filter(changedAtCond).fetchAll(db).map { $0.noteId } ),
                Set( try NoteLastWordCountChangeDayRecord.filter(changedAfterCond).fetchAll(db).map { $0.noteId } )
            )
        }
    }

    func recordLastWordCountChange(noteId: UUID, wordCount: Int, day: String) throws {
        _ = try write { db in
            let existingLastWordCountRecord = try NoteLastWordCountChangeDayRecord
                .filter(NoteLastWordCountChangeDayRecord.Columns.noteId == noteId.uuidString.uppercased())
                .fetchOne(db)
            if let existingLastWordCountRecord = existingLastWordCountRecord,
                existingLastWordCountRecord.lastWordCount != wordCount {
                existingLastWordCountRecord.lastChangeDay = day
                existingLastWordCountRecord.lastWordCount = wordCount
                existingLastWordCountRecord.updatedAt = BeamDate.now
                try existingLastWordCountRecord.save(db)
                return
            }
            if existingLastWordCountRecord == nil {
                let initialLastWordCountRecord = NoteLastWordCountChangeDayRecord(noteId: noteId, lastChangeDay: nil, lastWordCount: wordCount)
                try initialLastWordCountRecord.save(db)
            }
        }
    }
}

extension BeamManagerOwner {
    var noteStatsDBManager: NoteStatsDBManager? {
        try? manager(NoteStatsDBManager.self)
    }
}

extension BeamData {
    var noteStatsDBManager: NoteStatsDBManager? {
        currentDatabase?.noteStatsDBManager
    }
}

