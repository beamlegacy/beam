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
        let scoredDocuments = updatedDocuments.map {
            ScoredDocument(noteId: $0.id, title: $0.title, createdAt: $0.created_at, updatedAt: $0.updated_at,
                           created: $0.created_at > start, score: scores[$0.id]?.logScore,
                           captureToCount: scores[$0.id]?.captureToCount ?? 0)
        }
        return scoredDocuments.sorted { (lhs, rhs) in lhs > rhs }
    }
}
