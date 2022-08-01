//
//  KeychainDailyNoteScoreStore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 08/04/2022.
//

import Foundation
import BeamCore

class KeychainDailyNoteScoreStore: InMemoryDailyNoteScoreStore {
    public static let shared = KeychainDailyNoteScoreStore()

    private func toLastWordCountChange(dailyNoteScores: DailyNoteScores) -> NotesLastWordCountChangeDay {
        var lastWordCounts = NotesLastWordCountChangeDay()
        for (day, scores) in dailyNoteScores {
            for (noteId, score) in scores
            where score.lastWordCount != 0 && lastWordCounts[noteId]?.lastChangeDay ?? "0000-00-00" < day {
                lastWordCounts[noteId] = NoteLastWordCountChangeDay(noteId: noteId, lastChangeDay: day, lastWordCount: score.lastWordCount)
            }
        }
        return lastWordCounts
    }

    override init() {
        super.init()
        let decoder = JSONDecoder()
        lock {
            if let scoreData = Persistence.NoteScores.daily {
                scores = (try? decoder.decode(DailyNoteScores.self, from: scoreData)) ?? DailyNoteScores()
            }
            if let lastWordCountChangeData = Persistence.NoteScores.lastWordCountChange {
                notesLastWordCountChangeDay = (try? decoder.decode(NotesLastWordCountChangeDay.self, from: lastWordCountChangeData)) ?? NotesLastWordCountChangeDay()
            } else {
                //1st time migration
                notesLastWordCountChangeDay = toLastWordCountChange(dailyNoteScores: scores)
            }
        }
    }

    func save() {
        let encoder = JSONEncoder()
        lock {
            if let scoreData = try? encoder.encode(scores) {
                Persistence.NoteScores.daily = scoreData
            }
        }
    }
}
