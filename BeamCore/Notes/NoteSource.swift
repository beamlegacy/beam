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
        case frecencyAtAddition
    }

    public let urlId: UUID
    public let addedAt: Date
    public let type: SourceType
    public var sessionId: UUID?
    var longTermScore: LongTermUrlScore?
    var frecencyAtAddition: Float?

    var domain: String {
        guard let url = LinkStore.linkFor(urlId)?.url,
              let components = URLComponents(string: url) else {
            return "<???>"
        }
        return components.host ?? "<???>"
    }
    var addedAtDay: Date { Calendar.current.startOfDay(for: addedAt) }
    public var score: Float { (longTermScore?.score() ?? 0) / (frecencyAtAddition ?? 1) }
}

public class NoteSources: Codable {
    enum CodingKeys: CodingKey {
        case sources
    }
    private var sources: [UUID: NoteSource]
    @Published var changed: Bool = false

    init() {
        sources = [UUID: NoteSource]()
    }
    public var count: Int { sources.count }
    public var urlIds: [UUID] { Array(sources.keys) }

    func get(urlId: UUID) -> NoteSource? {
        return sources[urlId]
    }
    public func getAll() -> [NoteSource] {
        return Array(sources.values)
    }

    public func add(urlId: UUID, noteId: UUID, type: NoteSource.SourceType, date: Date = BeamDate.now, sessionId: UUID, frecency: Float? = nil, longTermScore: LongTermUrlScore? = nil, activeSources: ActiveSources? = nil) {
        let sourceToAdd = NoteSource(urlId: urlId, addedAt: date, type: type, sessionId: sessionId, longTermScore: longTermScore, frecencyAtAddition: frecency)
        switch type {
        case .suggestion:
            if let oldSource = sources[urlId],
               oldSource.type == .suggestion,
               oldSource.score < sourceToAdd.score {
                sources[urlId] = sourceToAdd
            } else if sources[urlId] == nil {
                sources[urlId] = sourceToAdd
            }
        case .user:
            sources[urlId] = sourceToAdd
            if let activeSources = activeSources {
                activeSources.addActiveSource(pageId: urlId, noteId: noteId)
            }
        }
        changed = true
    }
    public func refreshScore(score: LongTermUrlScore) {
        self.sources[score.urlId]?.longTermScore = score
    }

    // if sessionId is not nil, removes source only if its session id matches
    public func remove(urlId: UUID, noteId: UUID, isUserSourceProtected: Bool = true, sessionId: UUID? = nil, activeSources: ActiveSources? = nil) {
        guard let source = sources[urlId] else { return }
        if source.type == .user {
            if isUserSourceProtected {
                return
            } else if let activeSources = activeSources {
                    activeSources.removeActiveSource(pageId: urlId, noteId: noteId)
            }
        }
        if let sessionId = sessionId,
           let sourceSessionId = source.sessionId,
           sessionId != sourceSessionId { return }
        sources[urlId] = nil
        changed = true
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
