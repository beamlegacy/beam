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
    case webDomainIncrement //domain frecency update when visiting a url
    //beamnote interaction frecency events
    case noteCreate
    case noteVisit
    case noteBiDiLink
    case notePointAndShoot
}

private let webEventWeights: [FrecencyEventType: Float] = [
    .webRoot: 0,
    .webSearchBar: 1.5,
    .webLinkActivation: 1,
    .webFromNote: 1.5,
    .webDomainIncrement: 0.5
]
private let noteEventWeights: [[FrecencyEventType: Float]] = [
    [
        .noteCreate: 0,
        .noteVisit: 1,
        .noteBiDiLink: 5,
        .notePointAndShoot: 5
    ],
    [
        .noteCreate: 0,
        .noteVisit: 1,
        .noteBiDiLink: 1,
        .notePointAndShoot: 1
    ]
]

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
    public let halfLife: Float
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
    public var sortValue: Float!

    private func scoreSortValue(halfLife: Float) -> Float {
        guard lastScore > 0.0 else { return -Float.greatestFiniteMagnitude }
        return log(lastScore) + Float(lastTimestamp.timeIntervalSinceReferenceDate) * log(2) / halfLife
    }

    public init(id: UUID, lastTimestamp: Date, lastScore: Float, halfLife: Float) {
        self.id = id
        self.lastTimestamp = lastTimestamp
        self.lastScore = lastScore
        self.sortValue = scoreSortValue(halfLife: halfLife)
    }
    public init(id: UUID, lastTimestamp: Date, lastScore: Float, sortValue: Float) {
        self.id = id
        self.lastTimestamp = lastTimestamp
        self.lastScore = lastScore
        self.sortValue = sortValue
    }
    public func updated(date: Date, value: Float, halfLife: Float) -> FrecencyScore {
        if date > lastTimestamp {
            let duration = date.timeIntervalSince(lastTimestamp)
            let newValue = timeDecay(duration: Float(duration), halfLife: halfLife) * lastScore + value
            return FrecencyScore(id: id, lastTimestamp: date, lastScore: newValue, halfLife: halfLife)
        }
        let duration = lastTimestamp.timeIntervalSince(date)
        let newValue = lastScore + value * timeDecay(duration: Float(duration), halfLife: halfLife)
        return FrecencyScore(id: id, lastTimestamp: lastTimestamp, lastScore: newValue, halfLife: halfLife)
    }
}

public protocol FrecencyStorage {
    func fetchOne(id: UUID, paramKey: FrecencyParamKey) throws -> FrecencyScore?
    func save(score: FrecencyScore, paramKey: FrecencyParamKey) throws
    func save(scores: [FrecencyScore], paramKey: FrecencyParamKey) throws
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
            return FrecencyScore(id: id, lastTimestamp: date, lastScore: value, halfLife: param.halfLife)
        }
        return score.updated(date: date, value: value, halfLife: param.halfLife)
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
