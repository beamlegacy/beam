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

    override init() {
        super.init()
        let decoder = JSONDecoder()
        Self.backgroundQueue.sync {
            if let scoreData = Persistence.NoteScores.daily {
                scores = (try? decoder.decode(DailyNoteScores.self, from: scoreData)) ?? DailyNoteScores()
            }
        }
    }

    func save() {
        let encoder = JSONEncoder()
        Self.backgroundQueue.sync {
            if let scoreData = try? encoder.encode(scores) {
                Persistence.NoteScores.daily = scoreData
            }
        }
    }
}
