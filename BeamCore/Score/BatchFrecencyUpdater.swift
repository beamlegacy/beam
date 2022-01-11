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
    var params: [FrecencyParamKey: FrecencyParam] = FrecencyParameters
    let halfLife: Float
    var frecencyKey: FrecencyParamKey

    public init(frencencyStore: FrecencyStorage, frecencyKey: FrecencyParamKey = .webVisit30d0) {
        self.frecencyStore = frencencyStore
        self.frecencyKey = frecencyKey
        self.halfLife = params[frecencyKey]?.halfLife ?? (30 * 24 * 60 * 60)
    }

    private func getScore(urlId: UUID) -> FrecencyScore? {
        return scores[urlId] ?? (try? frecencyStore.fetchOne(id: urlId, paramKey: frecencyKey))
    }

    private func eventWeight(eventType: FrecencyEventType, param: FrecencyParam) -> Float {
        return param.eventWeights[eventType] ?? 1
    }

    public func add(urlId: UUID, date: Date, value: Float = 1, eventType: FrecencyEventType) {
        guard let param = params[frecencyKey] else { return }
        let weightedValue = value * eventWeight(eventType: eventType, param: param)
        guard let previousScore = getScore(urlId: urlId) else {
            let score = FrecencyScore(id: urlId, lastTimestamp: date, lastScore: weightedValue, halfLife: halfLife)
            scores[urlId] = score
            return
        }
        scores[urlId] = previousScore.updated(date: date, value: value, halfLife: halfLife)
    }

    public func saveAll() {
        do {
            try frecencyStore.save(scores: Array(scores.values), paramKey: frecencyKey)
        } catch {
            Logger.shared.logError(error.localizedDescription, category: .database)
        }
        scores = [UUID: FrecencyScore]()
    }
}
