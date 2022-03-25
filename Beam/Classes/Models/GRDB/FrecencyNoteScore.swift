//
//  FrecencyNoteScore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 28/12/2021.
//

import Foundation
import GRDB
import BeamCore

public struct FrecencyNoteRecord: Codable, BeamObjectProtocol {
    struct UniqueKey: Hashable {
        let frecencyKey: FrecencyParamKey
        let noteId: UUID
    }
    var uniqueKey: UniqueKey {
        UniqueKey(frecencyKey: frecencyKey, noteId: noteId)
    }

    public static let databaseUUIDEncodingStrategy = DatabaseUUIDEncodingStrategy.string
    static var beamObjectType: BeamObjectObjectType = .noteFrecency
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

    var beamObjectId: UUID {
        get { id }
        set { id = newValue }
    }

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

class NoteFrecencyApiSaveLimiter {
    private let saveOnApiLimit: Int // Save on Api every x local saves
    private var saveCount: Int = 0
    private var records = [UUID: FrecencyNoteRecord]()

    init(saveOnApiLimit: Int = 10) {
        self.saveOnApiLimit = saveOnApiLimit
    }

    func add(record: FrecencyNoteRecord) {
        if let previousRecord = records[record.id],
           record.lastAccessAt >= previousRecord.lastAccessAt {
            records[record.id] = record
        }
        if records[record.id] == nil {
            records[record.id] = record
        }
        saveCount += 1
    }
    func reset() {
        saveCount = 0
        records = [UUID: FrecencyNoteRecord]()
    }
    var recordsToSave: [FrecencyNoteRecord]? {
        guard saveCount >= saveOnApiLimit else { return nil }
        defer { reset() }
        return Array(records.values)
    }
}

public class GRDBNoteFrecencyStorage: FrecencyStorage {
    let db: GRDBDatabase
    private static let apiSaveLimiter = NoteFrecencyApiSaveLimiter()

    private(set) var batchSaveOnApiCompleted = false
    private(set) var softDeleteCompleted = false

    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }

    func resetApiSaveLimiter() {
        Self.apiSaveLimiter.reset()
    }
    public func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore? {
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
        let existingRecord = try? db.fetchOneFrecencyNote(noteId: score.id, paramKey: paramKey)
        let recordToSave = createOrUpdate(record: existingRecord, score: score, paramKey: paramKey)
        try db.saveFrecencyNote(recordToSave)
        Self.apiSaveLimiter.add(record: recordToSave)

        if AuthenticationManager.shared.isAuthenticated,
           Configuration.networkEnabled,
           let recordsToSaveOnNetwork = Self.apiSaveLimiter.recordsToSave {
            batchSaveOnApiCompleted = false
            try saveAllOnNetwork(recordsToSaveOnNetwork) { _ in
                self.batchSaveOnApiCompleted = true
            }
        }
    }

    public func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws {
        let noteIds = scores.map { $0.id }
        let recordsToUpdate = GRDBDatabase.shared.getFrecencyScoreValues(noteIds: noteIds, paramKey: paramKey)
        let recordsToSave = scores.map { createOrUpdate(record: recordsToUpdate[$0.id], score: $0, paramKey: paramKey) }
        try db.save(noteFrecencies: recordsToSave)

        guard AuthenticationManager.shared.isAuthenticated, Configuration.networkEnabled else { return }
        try saveAllOnNetwork(recordsToSave)
    }

    public func deleteAll(includedRemote: Bool, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) {
        do {
            try self.db.clearNoteFrecencies()
            if AuthenticationManager.shared.isAuthenticated && includedRemote {
                try self.deleteAllFromBeamObjectAPI { result in
                    networkCompletion?(result)
                }
            } else {
                networkCompletion?(.success(false))
            }
            return
        } catch {
            Logger.shared.logError("Unexpected error: \(error.localizedDescription).", category: .fileDB)
        }
        networkCompletion?(.success(false))
    }
}

extension GRDBNoteFrecencyStorage: BeamObjectManagerDelegate {
    static var conflictPolicy: BeamObjectConflictResolution = .replace
    internal static var backgroundQueue = DispatchQueue(label: "NoteFrecency BeamObjectManager backgroundQueue", qos: .userInitiated)

    private func deduplicated(records: [FrecencyNoteRecord]) -> [FrecencyNoteRecord] {
        let keyValues = records.map { ($0.uniqueKey, $0) }
        let deduplicatedDict = Dictionary(
            keyValues,
            uniquingKeysWith: { (leftRec, rightRec) in
                leftRec.lastAccessAt > rightRec.lastAccessAt ? leftRec : rightRec
            }
        )
        return Array(deduplicatedDict.values)
    }
    func remoteSoftDelete(noteId: UUID) {
        softDeleteCompleted = false
        let frecencies = db.fetchNoteFrecencies(noteId: noteId)
        let now = BeamDate.now
        let softDeleted = frecencies.map { (frecency) -> FrecencyNoteRecord in
            var softDeleted = frecency
            softDeleted.deletedAt = now
            return softDeleted
        }
        do {
            try db.save(noteFrecencies: softDeleted)
            try saveAllOnNetwork(softDeleted) { _ in
                self.softDeleteCompleted = true
            }
        } catch {
            Logger.shared.logError("Couldn't soft delete \(noteId) note frecencies \(error)", category: .frecencyNetwork)
        }
    }

    func receivedObjects(_ objects: [FrecencyNoteRecord]) throws {
        try self.db.save(noteFrecencies: deduplicated(records: objects))
    }

    func allObjects(updatedSince: Date?) throws -> [FrecencyNoteRecord] {
        try db.allNoteFrecencies(updatedSince: updatedSince)
    }

    func willSaveAllOnBeamObjectApi() {}

    func manageConflict(_ object: FrecencyNoteRecord,
                        _ remoteObject: FrecencyNoteRecord) throws -> FrecencyNoteRecord {
        fatalError("Managed by BeamObjectManager")
    }

    func saveObjectsAfterConflict(_ objects: [FrecencyNoteRecord]) throws {
        try self.db.save(noteFrecencies: objects)
    }

    func saveAllOnNetwork(_ frecencies: [FrecencyNoteRecord], _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectsAPI(frecencies) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved note frecencies on the BeamObject API",
                                               category: .frecencyNetwork)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving note frecencies on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .frecencyNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .frecencyNetwork)
            }
        }
    }

    private func saveOnNetwork(_ frecency: FrecencyNoteRecord, _ networkCompletion: ((Result<Bool, Error>) -> Void)? = nil) throws {
        Self.backgroundQueue.async { [weak self] in
            do {
                try self?.saveOnBeamObjectAPI(frecency) { result in
                    switch result {
                    case .success:
                        Logger.shared.logDebug("Saved note frecency on the BeamObject API",
                                               category: .frecencyNetwork)
                        networkCompletion?(.success(true))
                    case .failure(let error):
                        Logger.shared.logDebug("Error when saving note frecency on the BeamObject API with error: \(error.localizedDescription)",
                                               category: .frecencyNetwork)
                        networkCompletion?(.failure(error))
                    }
                }
            } catch {
                Logger.shared.logError(error.localizedDescription, category: .frecencyNetwork)
            }
        }
    }
}
