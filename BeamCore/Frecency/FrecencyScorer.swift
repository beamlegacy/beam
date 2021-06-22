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
    var timeStamp: Date
    var value: Float

    func value(at date: Date, halfLife: Float) -> Float {
        let duration = Float(date.timeIntervalSince(timeStamp))
        return value * timeDecay(duration: duration, halfLife: halfLife)
    }
}

public protocol FrecencyScorer {
    func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey)
    func rank(urlIds: [UInt64], paramKey: FrecencyParamKey, date: Date) -> [UInt64]
}

public protocol FrecencyStorage {
    func getOne(urlId: UInt64, paramKey: FrecencyParamKey) -> FrecencyScore?
    func getAll(urlIds: [UInt64], paramKey: FrecencyParamKey) -> [FrecencyScore]
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
            return  FrecencyScore(urlId: urlId, timeStamp: date, value: value)
        }
        let duration = Float(date.timeIntervalSince(score.timeStamp))
        let updatedValue = value + score.value * timeDecay(duration: duration, halfLife: param.halfLife)
        return FrecencyScore(urlId: urlId, timeStamp: date, value: updatedValue)
    }

    func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey) {
        guard let param = params[paramKey] else {return}
        let weightedValue = value * visitWeight(visitType: visitType, param: param)
        let score = updatedScore(urlId: urlId, value: weightedValue, date: date, param: param)
        storage.save(score: score, paramKey: param.key)
    }

    func rank(urlIds: [UInt64], paramKey: FrecencyParamKey, date: Date) -> [UInt64] {
        return [UInt64]()
//to be implemented depending on wether storage can compute exponetial function or not
//        let scores = storage.getAll(urlIds: urlIds, paramsName: params.name)
//        return scores
//            .sorted { $0.value(at: date, halfLife: params.halfLife) < $1.value(at: date, halfLife: params.halfLife) }
//            .map { $0.urlId }
    }
}
