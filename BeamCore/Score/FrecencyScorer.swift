//
//  FrecencyDbHandler.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 17/06/2021.
//

private let halfLife: Float = 30 * 24 * 60 * 60 //duration in seconds until when an event value is divided by 2

public enum FrecencyEventType {
    //web browsing frecency events
    case webRoot
    case webLinkActivation
    case webFromNote
    case webSearchBar
    //beamnote interaction frecency events
    case noteVisit
    case noteBiDiLink
    case notePointAndShoot
}

private let webEventWeights: [FrecencyEventType: Float] = [
    .webRoot: 0,
    .webSearchBar: 1.5,
    .webLinkActivation: 1,
    .webFromNote: 1.5
]
private let noteEventWeights: [[FrecencyEventType: Float]] = [
    [
        .noteVisit: 1,
        .noteBiDiLink: 5,
        .notePointAndShoot: 5
    ],
    [
        .noteVisit: 1,
        .noteBiDiLink: 1,
        .notePointAndShoot: 1
    ]
]

private func scoreSortValue(score: Float, timeStamp: Date, halfLife: Float) -> Float {
    guard score != 0.0 else { return -1 * Float.infinity }
    return log(score) + Float(timeStamp.timeIntervalSinceReferenceDate) * log(2) / halfLife
}

public enum FrecencyParamKey: Int, CaseIterable, Codable {
    //do not change raw values of existing cases to prevent messing with encoding in db
    case webVisit30d0 = 0
    case webReadingTime30d0 = 1
    case note30d0 = 2
    case note30d1 = 3
}

public struct FrecencyParam: Equatable {
    let key: FrecencyParamKey
    let eventWeights: [FrecencyEventType: Float]
    let halfLife: Float
}

public let FrecencyParameters: [FrecencyParamKey: FrecencyParam] = [
    .webReadingTime30d0: FrecencyParam(key: .webReadingTime30d0, eventWeights: webEventWeights, halfLife: halfLife),
    .webVisit30d0: FrecencyParam(key: .webVisit30d0, eventWeights: webEventWeights, halfLife: halfLife),
    .note30d0: FrecencyParam(key: .note30d0, eventWeights: noteEventWeights[0], halfLife: halfLife),
    .note30d1: FrecencyParam(key: .note30d1, eventWeights: noteEventWeights[1], halfLife: halfLife)
]

public struct FrecencyScore {
    public let id: UUID
    public var lastTimestamp: Date
    public var lastScore: Float
    public var sortValue: Float

    public init(id: UUID, lastTimestamp: Date, lastScore: Float, sortValue: Float) {
        self.id = id
        self.lastTimestamp = lastTimestamp
        self.lastScore = lastScore
        self.sortValue = sortValue
    }
}

public protocol FrecencyStorage {
    func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore?
    func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws
}

public protocol FrecencyScorer {
    func update(id: UUID, value: Float, eventType: FrecencyEventType, date: Date, paramKey: FrecencyParamKey)
}

public class ExponentialFrecencyScorer: FrecencyScorer {
    var storage: FrecencyStorage
    var params: [FrecencyParamKey: FrecencyParam]

    public init(storage: FrecencyStorage, params: [FrecencyParamKey: FrecencyParam] = FrecencyParameters) {
        self.storage = storage
        self.params = params
    }

    private func eventWeight(eventType: FrecencyEventType, param: FrecencyParam) -> Float {
        return param.eventWeights[eventType] ?? 1
    }

    private func updatedScore(id: UUID, value: Float, date: Date, param: FrecencyParam) -> FrecencyScore {
        guard let score = try? storage.fetchOne(id: id, paramKey: param.key) else {
            let sortValue: Float = scoreSortValue(score: value, timeStamp: date, halfLife: param.halfLife)
            return  FrecencyScore(id: id, lastTimestamp: date, lastScore: value, sortValue: sortValue)
        }
        let duration = Float(date.timeIntervalSince(score.lastTimestamp))
        let updatedValue = value + score.lastScore * timeDecay(duration: duration, halfLife: param.halfLife)
        let sortValue = scoreSortValue(score: updatedValue, timeStamp: date, halfLife: param.halfLife)
        return FrecencyScore(id: id, lastTimestamp: date, lastScore: updatedValue, sortValue: sortValue)
    }

    public func update(id: UUID, value: Float, eventType: FrecencyEventType, date: Date, paramKey: FrecencyParamKey) {
        guard let param = params[paramKey] else {return}
        let weightedValue = value * eventWeight(eventType: eventType, param: param)
        let score = updatedScore(id: id, value: weightedValue, date: date, param: param)
        do {
            try storage.save(score: score, paramKey: param.key)
        } catch {
            Logger.shared.logError("unable to save frecency for id: \(score.id): \(error)", category: .database)
        }
    }
}
