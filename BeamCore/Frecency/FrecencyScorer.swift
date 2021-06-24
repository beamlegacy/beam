//
//  FrecencyDbHandler.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 17/06/2021.
//

private let halfLife: Float = 30 * 24 * 60 * 60 //duration in seconds until when an event value is divided by 2
private let visitWeights: [VisitType: Float] = [
    .root: 0,
    .searchBar: 1.5,
    .linkActivation: 1,
    .fromNote: 1.5
]

private func timeDecay(duration: Float, halfLife: Float) -> Float {
    return exp(-(duration * log(2) / halfLife))
}
private func scoreSortValue(score: Float, timeStamp: Date, halfLife: Float) -> Float {
    guard score != 0.0 else { return -1 * Float.infinity }
    return log(score) + Float(timeStamp.timeIntervalSinceReferenceDate) * log(2) / halfLife
}

public enum FrecencyParamKey: String {
    case visit30d0
    case readingTime30d0
}

public struct FrecencyParam: Equatable {
    let key: FrecencyParamKey
    let visitWeights: [VisitType: Float]
    let halfLife: Float
}

let frecencyParameters: [FrecencyParamKey: FrecencyParam] = [
    .readingTime30d0: FrecencyParam(key: .readingTime30d0, visitWeights: visitWeights, halfLife: halfLife),
    .visit30d0: FrecencyParam(key: .readingTime30d0, visitWeights: visitWeights, halfLife: halfLife)
]

public struct FrecencyScore {
    let urlId: UInt64
    var lastTimestamp: Date
    var lastScore: Float
    var sortValue: Float
}

public protocol FrecencyScorer {
    func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey)
}

public protocol FrecencyStorage {
    func getOne(urlId: UInt64, paramKey: FrecencyParamKey) -> FrecencyScore?
    func save(score: FrecencyScore, paramKey: FrecencyParamKey)
}

class ExponentialFrecencyScorer: FrecencyScorer {
    var storage: FrecencyStorage
    var params: [FrecencyParamKey: FrecencyParam]

    init(storage: FrecencyStorage, params: [FrecencyParamKey: FrecencyParam]) {
        self.storage = storage
        self.params = params
    }

    private func visitWeight(visitType: VisitType, param: FrecencyParam) -> Float {
        return param.visitWeights[visitType] ?? 1
    }

    private func updatedScore(urlId: UInt64, value: Float, date: Date, param: FrecencyParam) -> FrecencyScore {
        guard let score = storage.getOne(urlId: urlId, paramKey: param.key) else {
            let sortValue: Float = scoreSortValue(score: value, timeStamp: date, halfLife: param.halfLife)
            return  FrecencyScore(urlId: urlId, lastTimestamp: date, lastScore: value, sortValue: sortValue)
        }
        let duration = Float(date.timeIntervalSince(score.lastTimestamp))
        let updatedValue = value + score.lastScore * timeDecay(duration: duration, halfLife: param.halfLife)
        let sortValue = scoreSortValue(score: updatedValue, timeStamp: date, halfLife: param.halfLife)
        return FrecencyScore(urlId: urlId, lastTimestamp: date, lastScore: updatedValue, sortValue: sortValue)
    }

    func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey) {
        guard let param = params[paramKey] else {return}
        let weightedValue = value * visitWeight(visitType: visitType, param: param)
        let score = updatedScore(urlId: urlId, value: weightedValue, date: date, param: param)
        storage.save(score: score, paramKey: param.key)
    }
}
