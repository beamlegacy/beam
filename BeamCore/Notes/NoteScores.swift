//
//  NoteScores.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 07/04/2022.
//

import Foundation

public class NoteScore: Codable {
    let noteId: UUID
    var minWordCount: Int?
    var maxWordCount: Int = 0
    var firstWordCount: Int?
    public var lastWordCount: Int = 0
    public var addedBidiLinkToCount: Int = 0
    public var captureToCount: Int = 0
    public var visitCount: Int = 0

    public init(noteId: UUID) {
        self.noteId = noteId
    }
    public var firstToLastDeltaWordCount: Int {
        lastWordCount - (firstWordCount ?? lastWordCount)
    }
    public var minToMaxDeltaWordCount: Int {
        maxWordCount - (minWordCount ?? maxWordCount)
    }

    public var logScore: Float {
        return log(1 + Float(addedBidiLinkToCount))
            + log(1 + Float(captureToCount))
            + 0.5 * log(1 + Float(visitCount))
            + log(1 + abs(Float(firstToLastDeltaWordCount)))
    }
}
public struct NoteLastWordCountChangeDay: Codable {
    public let noteId: UUID
    public let lastChangeDay: String?
    public let lastWordCount: Int

    public init(noteId: UUID, lastChangeDay: String?, lastWordCount: Int) {
        self.noteId = noteId
        self.lastChangeDay = lastChangeDay
        self.lastWordCount = lastWordCount
    }
}

public typealias NoteScoresById = [UUID: NoteScore]
public typealias DailyNoteScores = [String: NoteScoresById]
public typealias NotesLastWordCountChangeDay = [UUID: NoteLastWordCountChangeDay]

public protocol DailyNoteScoreStoreProtocol {
    func apply(to noteId: UUID, changes: (NoteScore) -> Void)
    func recordLastWordCountChange(noteId: UUID, wordCount: Int)
    func getNoteIdsLastChangedAtAndAfter(daysAgo: Int) -> (Set<UUID>, Set<UUID>)
    func cleanup(daysToKeep: Int)
    func getScore(noteId: UUID, daysAgo: Int) -> NoteScore?
    func getScores(daysAgo: Int) -> [UUID: NoteScore]
    func clear()
}

open class InMemoryDailyNoteScoreStore: DailyNoteScoreStoreProtocol {
    public var scores = DailyNoteScores()
    public var notesLastWordCountChangeDay = NotesLastWordCountChangeDay()
    public static var backgroundQueue: DispatchQueue = DispatchQueue(label: "InMemoryDailyNoteScoreStore backgroundQueue")

    public init() {}
    public func apply(to noteId: UUID, changes: (NoteScore) -> Void) {
        guard let localDay = BeamDate.now.localDayString() else { return }
        Self.backgroundQueue.sync {
            var dayScores = self.scores[localDay] ?? NoteScoresById()
            let scoreToUpdate = dayScores[noteId] ?? NoteScore(noteId: noteId)
            changes(scoreToUpdate)
            dayScores[noteId] = scoreToUpdate
            self.scores[localDay] = dayScores
        }
    }

    public func recordLastWordCountChange(noteId: UUID, wordCount: Int) {
        guard let localDay = BeamDate.now.localDayString() else { return }
        Self.backgroundQueue.sync {
            if let lastWordCount = notesLastWordCountChangeDay[noteId]?.lastWordCount,
               lastWordCount != wordCount {
                notesLastWordCountChangeDay[noteId] = NoteLastWordCountChangeDay(noteId: noteId, lastChangeDay: localDay, lastWordCount: wordCount)
                return
            }
            if notesLastWordCountChangeDay[noteId] == nil {
                notesLastWordCountChangeDay[noteId] = NoteLastWordCountChangeDay(noteId: noteId, lastChangeDay: nil, lastWordCount: wordCount)
            }
        }
    }

    public func getNoteIdsLastChangedAtAndAfter(daysAgo: Int) -> (Set<UUID>, Set<UUID>) {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day else { return (Set<UUID>(), Set<UUID>()) }
        return Self.backgroundQueue.sync {
            return (
                Set( (notesLastWordCountChangeDay.filter { $0.value.lastChangeDay == day}).keys),
                Set( (notesLastWordCountChangeDay.filter { $0.value.lastChangeDay ?? "0000-00-00" > day}).keys)
            )
        }
    }

    public func cleanup(daysToKeep: Int) {
        let existingDays =  scores.keys
        let daysToKeep = daysToKeep
        let bound = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysToKeep, to: BeamDate.now)?.localDayString() ?? "0000-00-00"
        Self.backgroundQueue.sync {
            for day in existingDays where day <= bound {
                scores[day] = nil
            }
        }
    }

    public func getScore(noteId: UUID, daysAgo: Int) -> NoteScore? {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day else { return nil }
        return Self.backgroundQueue.sync {
            scores[day]?[noteId]
        }
    }

    public func getScores(daysAgo: Int) -> [UUID: NoteScore] {
        let day = Calendar(identifier: .iso8601).date(byAdding: .day, value: -daysAgo, to: BeamDate.now)?.localDayString()
        guard let day = day else { return  [UUID: NoteScore]() }
        return Self.backgroundQueue.sync {
            scores[day] ?? [UUID: NoteScore]()
        }
    }

    public func clear() {
        Self.backgroundQueue.sync {
            scores = DailyNoteScores()
        }
    }
}

public class NoteScorer {
    static let daysToKeep: Int = 2
    static let isoCalendar = Calendar(identifier: .iso8601)
    public static var shared = NoteScorer(dailyStorage: InMemoryDailyNoteScoreStore())

    let dailyStorage: DailyNoteScoreStoreProtocol

    public init(dailyStorage: DailyNoteScoreStoreProtocol = InMemoryDailyNoteScoreStore()) {
        self.dailyStorage = dailyStorage
    }

    private func updateLocalDaily(noteId: UUID, changes: (NoteScore) -> Void) {
        dailyStorage.apply(to: noteId, changes: changes)
    }

    func updateWordCount(noteId: UUID, wordCount: Int) {
        updateLocalDaily(noteId: noteId) {
            if let minWordCount = $0.minWordCount {
                $0.minWordCount = min(minWordCount, wordCount)
            } else { $0.minWordCount = wordCount }
            $0.maxWordCount = max($0.maxWordCount, wordCount)
            $0.firstWordCount = $0.firstWordCount ?? wordCount
            $0.lastWordCount = wordCount
        }
        dailyStorage.recordLastWordCountChange(noteId: noteId, wordCount: wordCount)
    }

    public func getNoteIdsLastChangedAtAndAfter(daysAgo: Int = 1)  -> (Set<UUID>, Set<UUID>) {
        dailyStorage.getNoteIdsLastChangedAtAndAfter(daysAgo: daysAgo)
    }

    public func incrementBidiLinkToCount(noteId: UUID) {
        updateLocalDaily(noteId: noteId) {
            $0.addedBidiLinkToCount += 1
        }
    }

    public func incrementCaptureToCount(noteId: UUID) {
        updateLocalDaily(noteId: noteId) {
            $0.captureToCount += 1
        }
    }

    public func incrementVisitCount(noteId: UUID) {
        updateLocalDaily(noteId: noteId) {
            $0.visitCount += 1
        }
    }

    public func cleanup(daysToKeep: Int? = nil) {
        let daysToKeep = daysToKeep ?? Self.daysToKeep
        dailyStorage.cleanup(daysToKeep: daysToKeep)
    }

    func getLocalDailyScore(noteId: UUID, daysAgo: Int = 1) -> NoteScore? {
        return dailyStorage.getScore(noteId: noteId, daysAgo: daysAgo)
    }

    public func getLocalDailyScores(daysAgo: Int = 1) -> [UUID: NoteScore] {
        return dailyStorage.getScores(daysAgo: daysAgo)
    }
}
