//
//  NoteSource.swift
//  BeamCore
//
//  Created by Paul Lefkopoulos on 19/07/2021.
//

import Foundation

public struct NoteSource: Codable {
    public enum SourceType: Int, Codable, Comparable {
        case user
        case suggestion
        public static func < (lhs: SourceType, rhs: SourceType) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum CodingKeys: CodingKey {
        case urlId
        case addedAt
        case type
        case sessionId
    }

    let urlId: UInt64
    let addedAt: Date
    let type: SourceType
    var sessionId: UUID?
    var longTermScore: LongTermUrlScore?

    var domain: String {
        guard let url = LinkStore.linkFor(urlId)?.url,
              let components = URLComponents(string: url) else {
            return "<???>"
        }
        return components.host ?? "<???>"
    }
    var addedAtDay: Date { Calendar.current.startOfDay(for: addedAt) }
    var score: Float { longTermScore?.score() ?? 0 }
}

public class NoteSources: Codable {
    enum CodingKeys: CodingKey {
        case sources
    }
    private var sources: [UInt64: NoteSource]

    init() {
        sources = [UInt64: NoteSource]()
    }
    var count: Int { sources.count }
    public var urlIds: [UInt64] { Array(sources.keys) }

    func get(urlId: UInt64) -> NoteSource? {
        return sources[urlId]
    }

    public func add(urlId: UInt64, type: NoteSource.SourceType, date: Date = BeamDate.now, sessionId: UUID) {
        let sourceToAdd = NoteSource(urlId: urlId, addedAt: date, type: type, sessionId: sessionId)
        switch type {
        case .suggestion: sources[urlId] = sources[urlId] ?? sourceToAdd
        case .user: sources[urlId] = sourceToAdd
        }
    }
    public func refreshScore(score: LongTermUrlScore) {
        self.sources[score.urlId]?.longTermScore = score
    }

    // if sessionId is not nil, removes source only if its session id matches
    func remove(urlId: UInt64, isUserSourceProtected: Bool = true, sessionId: UUID? = nil) {
        guard let source = sources[urlId] else { return }
        if source.type == .user, isUserSourceProtected { return }
        if let sessionId = sessionId,
           let sourceSessionId = source.sessionId,
           sessionId != sourceSessionId { return }
        sources[urlId] = nil
    }

    private func commonLowerThan(lhs: NoteSource, rhs: NoteSource) -> Bool {
        return (lhs.type, rhs.score) < (rhs.type, lhs.score)
    }

    func sortedByDomain(ascending: Bool = true) -> [NoteSource] {
        return sources.values.sorted {
            let firstPredicate =  ascending ? $0.domain < $1.domain : $1.domain < $0.domain
            return $0.domain == $1.domain ? commonLowerThan(lhs: $0, rhs: $1) : firstPredicate
        }
    }

    func sortedByAddedDay(ascending: Bool = true) -> [NoteSource] {
        return sources.values.sorted {
            let firstPredicate =  ascending ? $0.addedAtDay < $1.addedAtDay : $1.addedAtDay < $0.addedAtDay
            return $0.addedAtDay == $1.addedAtDay ? commonLowerThan(lhs: $0, rhs: $1) : firstPredicate
        }
    }

    func sortedByScoreDesc() -> [NoteSource] {
        return sources.values.sorted(by: commonLowerThan)
    }
}
