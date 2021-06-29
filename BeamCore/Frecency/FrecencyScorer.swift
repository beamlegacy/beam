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

public enum FrecencyParamKey: Int, CaseIterable {
    case visit30d0
    case readingTime30d0
}

public struct FrecencyParam: Equatable {
    let key: FrecencyParamKey
    let visitWeights: [VisitType: Float]
    let halfLife: Float
}

public let frecencyParameters: [FrecencyParamKey: FrecencyParam] = [
    .readingTime30d0: FrecencyParam(key: .readingTime30d0, visitWeights: visitWeights, halfLife: halfLife),
    .visit30d0: FrecencyParam(key: .visit30d0, visitWeights: visitWeights, halfLife: halfLife)
]

public struct FrecencyScore {
    public let urlId: UInt64
    public var lastTimestamp: Date
    public var lastScore: Float
    public var sortValue: Float

    public init(urlId: UInt64, lastTimestamp: Date, lastScore: Float, sortValue: Float) {
        self.urlId = urlId
        self.lastTimestamp = lastTimestamp
        self.lastScore = lastScore
        self.sortValue = sortValue
    }
}

public protocol FrecencyScorer {
    func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey)
}

public protocol FrecencyStorage {
    func fetchOne(urlId: UInt64, paramKey: FrecencyParamKey) throws -> FrecencyScore?
    func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws
}

public class ExponentialFrecencyScorer: FrecencyScorer {
    var storage: FrecencyStorage
    var params: [FrecencyParamKey: FrecencyParam]

    public init(storage: FrecencyStorage, params: [FrecencyParamKey: FrecencyParam] = frecencyParameters) {
        self.storage = storage
        self.params = params
    }

    private func visitWeight(visitType: VisitType, param: FrecencyParam) -> Float {
        return param.visitWeights[visitType] ?? 1
    }

    private func updatedScore(urlId: UInt64, value: Float, date: Date, param: FrecencyParam) -> FrecencyScore {
        guard let score = try? storage.fetchOne(urlId: urlId, paramKey: param.key) else {
            let sortValue: Float = scoreSortValue(score: value, timeStamp: date, halfLife: param.halfLife)
            return  FrecencyScore(urlId: urlId, lastTimestamp: date, lastScore: value, sortValue: sortValue)
        }
        let duration = Float(date.timeIntervalSince(score.lastTimestamp))
        let updatedValue = value + score.lastScore * timeDecay(duration: duration, halfLife: param.halfLife)
        let sortValue = scoreSortValue(score: updatedValue, timeStamp: date, halfLife: param.halfLife)
        return FrecencyScore(urlId: urlId, lastTimestamp: date, lastScore: updatedValue, sortValue: sortValue)
    }

    public func update(urlId: UInt64, value: Float, visitType: VisitType, date: Date, paramKey: FrecencyParamKey) {
        guard let param = params[paramKey] else {return}
        let weightedValue = value * visitWeight(visitType: visitType, param: param)
        let score = updatedScore(urlId: urlId, value: weightedValue, date: date, param: param)
        do {
            try storage.save(score: score, paramKey: param.key)
        } catch {
            Logger.shared.logError("unable to save frecency for urlId: \(score.urlId): \(error)", category: .database)
        }
    }
}
