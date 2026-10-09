//
//  FrecencyNoteScore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 28/12/2021.
//

import Foundation
import GRDB
import BeamCore

public struct FrecencyNoteRecord: Codable, Hashable {
    struct UniqueKey: Hashable {
        let frecencyKey: FrecencyParamKey
        let noteId: UUID
    }
    var uniqueKey: UniqueKey {
        UniqueKey(frecencyKey: frecencyKey, noteId: noteId)
    }

    public static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.uppercaseString
    static let BeamElementForeignKey = ForeignKey([FrecencyNoteRecord.Columns.noteId], to: [BeamElementRecord.Columns.noteId])

    var id: UUID = UUID()
    var noteId: UUID
    var lastAccessAt: Date
    /// Frecency internal score. Not suited for querying.
    var frecencyScore: Float
    /// Frecency score to sort notes in a search query.
    var frecencySortScore: Float
    var frecencyKey: FrecencyParamKey
    var createdAt: Date = BeamDate.now
    var updatedAt: Date = BeamDate.now
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case noteId
        case lastAccessAt
        case frecencyScore
        case frecencySortScore
        case frecencyKey
        case createdAt
        case updatedAt
        case deletedAt
    }

    func copy() -> FrecencyNoteRecord {
        FrecencyNoteRecord(
            id: id,
            noteId: noteId,
            lastAccessAt: lastAccessAt,
            frecencyScore: frecencyScore,
            frecencySortScore: frecencySortScore,
            frecencyKey: frecencyKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}

extension FrecencyNoteRecord: FetchableRecord {
    public init(row: Row) {
        id = row[Columns.id]
        noteId = row[Columns.noteId]
        lastAccessAt = row[Columns.lastAccessAt]
        frecencyScore = row[Columns.frecencyScore]
        frecencySortScore = row[Columns.frecencySortScore]
        frecencyKey = row[Columns.frecencyKey]
        createdAt = row[Columns.createdAt]
        updatedAt = row[Columns.updatedAt]
        deletedAt = row[Columns.deletedAt]
    }
}

extension FrecencyNoteRecord: PersistableRecord {
    public func encode(to container:  inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.noteId] = noteId.uuidString
        container[Columns.lastAccessAt] = lastAccessAt
        container[Columns.frecencyScore] = frecencyScore
        container[Columns.frecencySortScore] = frecencySortScore
        container[Columns.frecencyKey] = frecencyKey
        container[Columns.createdAt] = createdAt
        container[Columns.updatedAt] = updatedAt
        container[Columns.deletedAt] = deletedAt
        }
}

extension FrecencyNoteRecord: TableRecord {
    enum Columns: String, ColumnExpression {
        case id, noteId, lastAccessAt, frecencyScore, frecencySortScore, frecencyKey,
        createdAt, updatedAt, deletedAt
    }
}

public class GRDBNoteFrecencyStorage: FrecencyStorage {
    let providedDb: BeamNoteLinksAndRefsManager?
    var db: BeamNoteLinksAndRefsManager? {
        let currentDb = providedDb ?? BeamData.shared.noteLinksAndRefsManager
        if currentDb == nil {
            Logger.shared.logError("GRDBNoteFrecencyStorage has no BeamNoteLinksAndRefsManager available", category: .browsingTreeNetwork)
        }
        return currentDb
    }

    init(db providedDb: BeamNoteLinksAndRefsManager? = nil) {
        self.providedDb = providedDb
    }

    public func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
        guard let db = db else { return nil }
        do {
            if let record = try db.fetchOneFrecencyNote(noteId: id, paramKey: paramKey) {
                return FrecencyScore(id: record.noteId,
                                     lastTimestamp: record.lastAccessAt,
                                     lastScore: record.frecencyScore,
                                     sortValue: record.frecencySortScore)
            }
        } catch {
            Logger.shared.logError("unable to fetch frecency for urlId \(id): \(error)", category: .database)
        }
        return nil
    }
    public func fetchMany(ids: [UUID], paramKey: FrecencyParamKey) -> [UUID: FrecencyScore] {
        guard let db = db else { return [UUID: FrecencyScore]() }
        let keyValues = db.getFrecencyScoreValues(noteIds: ids, paramKey: paramKey)
            .map { (id, record) in
                (id, FrecencyScore(id: record.noteId,
                       lastTimestamp: record.lastAccessAt,
                       lastScore: record.frecencyScore,
                       sortValue: record.frecencySortScore))
            }
        return Dictionary(uniqueKeysWithValues: keyValues)
    }

    private func createOrUpdate(record: FrecencyNoteRecord?, score: FrecencyScore, paramKey: FrecencyParamKey) -> FrecencyNoteRecord {
        if var updatedRecord = record {
            updatedRecord.lastAccessAt = score.lastTimestamp
            updatedRecord.frecencyScore = score.lastScore
            updatedRecord.frecencySortScore = score.sortValue
            updatedRecord.updatedAt = BeamDate.now
            return updatedRecord
        } else {
            let createdRecord = FrecencyNoteRecord(
               noteId: score.id,
               lastAccessAt: score.lastTimestamp,
               frecencyScore: score.lastScore,
               frecencySortScore: score.sortValue,
               frecencyKey: paramKey)
            return createdRecord
        }
    }

    public func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws {
        guard let db = db else { return }
        let existingRecord = try? db.fetchOneFrecencyNote(noteId: score.id, paramKey: paramKey)
        let recordToSave = createOrUpdate(record: existingRecord, score: score, paramKey: paramKey)
        try db.saveFrecencyNote(recordToSave)
    }

    public func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws {
        guard let db = db else { return }
        let noteIds = scores.map { $0.id }
        guard let recordsToUpdate = BeamData.shared.noteLinksAndRefsManager?.getFrecencyScoreValues(noteIds: noteIds, paramKey: paramKey) else {
            throw BeamDataError.databaseNotFound
        }
        let recordsToSave = scores.map { createOrUpdate(record: recordsToUpdate[$0.id], score: $0, paramKey: paramKey) }
        try db.save(noteFrecencies: recordsToSave)
    }

    /// Marks the frecency records of a deleted note as deleted.
    public func softDelete(noteId: UUID) {
        guard let db = db else { return }
        let now = BeamDate.now
        let softDeleted = db.fetchNoteFrecencies(noteId: noteId).map { frecency -> FrecencyNoteRecord in
            var softDeleted = frecency
            softDeleted.deletedAt = now
            return softDeleted
        }
        do {
            try db.save(noteFrecencies: softDeleted)
        } catch {
            Logger.shared.logError("Couldn't soft delete frecencies of note \(noteId): \(error)", category: .database)
        }
    }

    public func deleteAll() {
        guard let db = db else { return }
        do {
            try db.clearNoteFrecencies()
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .fileDB)
        }
    }
}

