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
    var lastWordCount: Int = 0
    var addedBidiLinkToCount: Int = 0
    public var captureToCount: Int = 0
    var visitCount: Int = 0

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

public typealias NoteScoresById = [UUID: NoteScore]
public typealias DailyNoteScores = [String: NoteScoresById]

public protocol DailyNoteScoreStoreProtocol {
    func apply(to noteId: UUID, changes: (NoteScore) -> Void)
    func cleanup(daysToKeep: Int)
    func getScore(noteId: UUID, daysAgo: Int) -> NoteScore?
    func getScores(daysAgo: Int) -> [UUID: NoteScore]
    func clear()
}

open class InMemoryDailyNoteScoreStore: DailyNoteScoreStoreProtocol {
    public var scores = DailyNoteScores()
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
