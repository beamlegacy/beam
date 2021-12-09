//
//  BatchFrecencyUpdater.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 05/11/2021.
//

import Foundation

public class BatchFrecencyUpdater {
    var scores = [UUID: FrecencyScore]()
    var frecencyStore: FrecencyStorage
    var params: [FrecencyParamKey: FrecencyParam]
    let halfLife: Float
    static var frecencyKey: FrecencyParamKey = .webVisit30d0

    public init(frencencyStore: FrecencyStorage, params: [FrecencyParamKey: FrecencyParam] = FrecencyParameters) {
        self.frecencyStore = frencencyStore
        self.params = params
        self.halfLife = params[Self.frecencyKey]?.halfLife ?? (30 * 24 * 60 * 60)
    }

    private func getScore(urlId: UUID) -> FrecencyScore? {
        return scores[urlId] ?? (try? frecencyStore.fetchOne(id: urlId, paramKey: BatchFrecencyUpdater.frecencyKey))
    }

    public func add(urlId: UUID, date: Date) {
        guard let previousScore = getScore(urlId: urlId) else {
            let score = FrecencyScore(id: urlId, lastTimestamp: date, lastScore: 1.0, halfLife: halfLife)
            scores[urlId] = score
            return
        }
        scores[urlId] = previousScore.updated(date: date, value: 1, halfLife: halfLife)
    }

    public func saveAll() {
        do {
            try frecencyStore.save(scores: Array(scores.values), paramKey: Self.frecencyKey)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
        }
        scores = [UUID: FrecencyScore]()
    }
}
