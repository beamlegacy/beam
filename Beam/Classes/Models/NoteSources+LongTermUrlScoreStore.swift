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
        DispatchQueue.global().async {
            let scores = scoreStore.getMany(urlIds: self.urlIds)
            for score in scores {
                self.refreshScore(score: score)
            }
            completion()
        }
    }
}
