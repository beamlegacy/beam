//
//  DailyNoteScore+GRDB.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 24/08/2022.
//

import Foundation
import BeamCore
import GRDB

class DailyNoteScoreRecord: Codable, NoteScoreProtocol {
    public static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString

    var id: UUID = UUID()
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    let localDay: String
    public let noteId: UUID
    public var minWordCount: Int?
    public var maxWordCount: Int = 0
    public var firstWordCount: Int?
    public var lastWordCount: Int = 0
    public var addedBidiLinkToCount: Int = 0
    public var captureToCount: Int = 0
    public var visitCount: Int = 0

    public init(noteId: UUID, localDay: String) {
        self.noteId = noteId
        self.localDay = localDay
    }
}
extension DailyNoteScoreRecord: FetchableRecord {}
extension DailyNoteScoreRecord: PersistableRecord {
    enum Columns: String, ColumnExpression {
            case id, createdAt, updatedAt, localDay, noteId, minWordCount, maxWordCount, firstWordCount
            case lastWordCOunt, addedBidiLinkToCount, captureToCount, visitCount
        }
}
extension DailyNoteScoreRecord: TableRecord {}
extension DailyNoteScoreRecord: Identifiable {}

class NoteLastWordCountChangeDayRecord: Codable {
    public static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString

    var id: UUID = UUID()
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    let noteId: UUID
    var lastChangeDay: String?
    var lastWordCount: Int

    public init(noteId: UUID, lastChangeDay: String?, lastWordCount: Int) {
        self.noteId = noteId
        self.lastChangeDay = lastChangeDay
        self.lastWordCount = lastWordCount
    }
}
extension NoteLastWordCountChangeDayRecord: FetchableRecord {}
extension NoteLastWordCountChangeDayRecord: PersistableRecord {
    enum Columns: String, ColumnExpression {
            case id, createdAt, updatedAt, lastChangeDay, noteId
        }
}
extension NoteLastWordCountChangeDayRecord: TableRecord {}
extension NoteLastWordCountChangeDayRecord: Identifiable {}

class GRDBDailyNoteScoreStore: DailyNoteScoreStoreProtocol {
    func apply(to noteId: UUID, changes: @escaping (NoteScoreProtocol) -> Void) {
        guard let localDay = BeamDate.now.localDayString(),
              let db = db else { return }
        do {
            try db.applyScoreChange(noteId: noteId, localDay: localDay, changes: changes)
        } catch {
            Logger.shared.logError("Couldn't change daily score for noteId: \(noteId) at: \(localDay): \(error)", category: .database)
        }
    }

    func recordLastWordCountChange(noteId: UUID, wordCount: Int) {
        guard let localDay = BeamDate.now.localDayString(),
              let db = db else { return }
        do {
            try db.recordLastWordCountChange(noteId: noteId, wordCount: wordCount, day: localDay)
        } catch {
            Logger.shared.logError("Couldn't record last word count change for noteId \(noteId): \(error)", category: .database)
        }
    }

    func getNoteIdsLastChangedAtAndAfter(daysAgo: Int) -> (Set<UUID>, Set<UUID>) {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day,
            let db = db else { return (Set<UUID>(), Set<UUID>()) }
        do {
            return try db.getNoteIdsLastChangedAtAndAfter(day: day)
        } catch {
            Logger.shared.logError("Couldn't get noteIds changed at \(day): \(error)", category: .database)
            return (Set<UUID>(), Set<UUID>())
        }
    }

    func cleanup(daysToKeep: Int) {
        guard let bound = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysToKeep, to: BeamDate.now)?.localDayString(),
                let db = db else { return }
        do {
            try db.clearDailyNoteScores(before: bound)
        } catch {
            Logger.shared.logError("Couldn't clear daily note scores before \(bound): \(error)", category: .database)
        }
    }

    func getScore(noteId: UUID, daysAgo: Int) -> NoteScoreProtocol? {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day,
              let db = db else { return nil }
        do {
            return try db.getDailyNoteScore(noteId: noteId, localDay: day)
        } catch {
            Logger.shared.logError("Couldn't get daily note score for \(noteId) at \(day): \(error)", category: .database)
            return nil
        }
    }

    func getScores(daysAgo: Int) -> [UUID : NoteScoreProtocol] {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day,
              let db = db else { return [UUID:NoteScoreProtocol]() }
        do {
            return try db.getDailyNoteScores(localDay: day)
        } catch {
            Logger.shared.logError("Couldn't get daily note scores at \(day): \(error)", category: .database)
            return [UUID:NoteScoreProtocol]()
        }
    }

    func clear() {
        guard let db = db else { return }
        do {
            try db.clearDailyNoteScores()
        } catch {
            Logger.shared.logError("Couldn't clear daily note scores: \(error)", category: .database)
        }
    }

    let providedDb: NoteStatsDBManager?
    var db: NoteStatsDBManager? {
        let currentDb = providedDb ?? BeamData.shared.noteStatsDBManager
        if currentDb == nil {
            Logger.shared.logError("GRDBDailyNoteScoreStore has no noteStatsDBManager available", category: .database)
        }
        return currentDb
    }

    static let shared = GRDBDailyNoteScoreStore()
    init(db providedDb: NoteStatsDBManager? = nil) {
        self.providedDb = providedDb
    }

}
