//
//  NoteDailySummary.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 12/04/2022.
//

import Foundation
import BeamCore

struct ScoredDocument {
    public let noteId: UUID
    public let title: String
    public let createdAt: Date
    public let updatedAt: Date
    public let created: Bool
    public let score: NoteScore
    public let captureToCount: Int
}

class NoteDailySummary {
    let noteScorer: NoteScorer

    init(dailyScoreStore: DailyNoteScoreStoreProtocol = KeychainDailyNoteScoreStore.shared) {
        self.noteScorer = NoteScorer(dailyStorage: dailyScoreStore)
    }

    private func dayBounds(daysAgo: Int) -> (Date, Date) {
        let cal = Calendar(identifier: .iso8601)
        let now = BeamDate.now
        let nowMinusDaysAgo = cal.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let start = cal.startOfDay(for: nowMinusDaysAgo)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    func get(daysAgo: Int = 1, filtered: Bool = true) throws -> [ScoredDocument] {
        let documentManager = DocumentManager()
        let (start, end) = dayBounds(daysAgo: daysAgo)
        let updatedDocuments = try documentManager.fetchAllNotesUpdatedBetween(date0: start, date1: end)
        let scores = noteScorer.getLocalDailyScores(daysAgo: daysAgo)
        let scoredDocuments = updatedDocuments.compactMap { (doc) -> ScoredDocument? in
            let created = doc.created_at > start
            guard let score = scores[doc.id],
                  (score.minToMaxDeltaWordCount != 0) || created || !filtered else { return nil }
            return ScoredDocument(noteId: doc.id, title: doc.title, createdAt: doc.created_at, updatedAt: doc.updated_at,
                           created: created, score: score,
                           captureToCount: score.captureToCount)
        }
        return scoredDocuments.sorted { (lhs, rhs) in lhs.score.logScore > rhs.score.logScore }
    }
}
