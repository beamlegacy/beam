//
//  NoteSources+LongTermUrlScoreStore.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 21/07/2021.
//

import Foundation
import BeamCore

extension NoteSources {
    func refreshScores(scoreStore: LongTermUrlScoreStoreProtocol = LongTermUrlScoreStore.shared,
                       completion: @escaping () -> Void) {
        let urlIds = self.urlIds
        DispatchQueue.database.async {
            let scores = scoreStore.getMany(urlIds: urlIds).values
            DispatchQueue.main.async {
                for score in scores {
                    self.refreshScore(score: score)
                }
            }
            completion()
        }
    }

    func refreshScores(scoreStore: LongTermUrlScoreStoreProtocol = LongTermUrlScoreStore.shared) {
        let urlIds = self.urlIds
        let scores = scoreStore.getMany(urlIds: urlIds).values
        for score in scores {
            self.refreshScore(score: score)
        }
    }
}
