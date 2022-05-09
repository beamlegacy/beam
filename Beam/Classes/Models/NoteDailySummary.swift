//
//  NoteDailySummary.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 12/04/2022.
//

import Foundation
import BeamCore

struct ScoredDocument: Comparable {
    let noteId: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let created: Bool
    let score: Float?
    let captureToCount: Int

    static func < (lhs: ScoredDocument, rhs: ScoredDocument) -> Bool {
        if let lScore = lhs.score,
           let rScore = rhs.score {
            return lScore < rScore
        }
        if lhs.score == nil {
            return true
        }
        if rhs.score == nil {
            return false
        }
        return lhs.updatedAt < rhs.updatedAt
    }
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

    func get(daysAgo: Int = 1) throws -> [ScoredDocument] {
        let documentManager = DocumentManager()
        let (start, end) = dayBounds(daysAgo: daysAgo)
        let updatedDocuments = try documentManager.fetchAllNotesUpdatedBetween(date0: start, date1: end)
        let scores = noteScorer.getLocalDailyScores(daysAgo: daysAgo)
        let scoredDocuments = updatedDocuments.compactMap { (doc) -> ScoredDocument? in
            let created = doc.created_at > start
            guard let score = scores[doc.id],
                  (score.minToMaxDeltaWordCount != 0) || created else { return nil }
            return ScoredDocument(noteId: doc.id, title: doc.title, createdAt: doc.created_at, updatedAt: doc.updated_at,
                           created: created, score: score.logScore,
                           captureToCount: score.captureToCount)
        }
        return scoredDocuments.sorted { (lhs, rhs) in lhs > rhs }
    }
}
