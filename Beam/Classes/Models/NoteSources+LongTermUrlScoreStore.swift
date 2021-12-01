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
                       completion: @escaping () -> Void = {}) {
        let urlIds = self.urlIds
        DispatchQueue.global().async {
            let scores = scoreStore.getMany(urlIds: urlIds)
            DispatchQueue.main.async {
                for score in scores {
                    self.refreshScore(score: score)
                }
            }
            completion()
        }
    }
}
