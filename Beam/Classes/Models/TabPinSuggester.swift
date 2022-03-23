//
//  TabPinSuggester.swift
//  Beam
//
//  Created by Paul Lefkopoulos on 09/03/2022.
//

import Foundation
import BeamCore
import GRDB
import Promises

struct TabPinSuggestion: Codable {
    var id = UUID()
    var createdAt = BeamDate.now
    var updatedAt = BeamDate.now
    let domainPath0: String
}
extension TabPinSuggestion: FetchableRecord {}
extension TabPinSuggestion: PersistableRecord {}
extension TabPinSuggestion: TableRecord {
    enum Columns: String, ColumnExpression {
            case id, createAt, updatedAt, domainPath0
        }
}
extension TabPinSuggestion: Identifiable {}

class TabPinSuggestionMemory {
    let db: GRDBDatabase
    init(db: GRDBDatabase = GRDBDatabase.shared) {
        self.db = db
    }
    func addTabPinSuggestion(domainPath0: String) {
        do {
            try db.addTabPinSuggestion(domainPath0: domainPath0)
        } catch {
            Logger.shared.logError("Couldn't save tab pin suggestion for \(domainPath0): \(error)", category: .database)
        }
    }
    var tabPinSuggestionCount: Int {
        db.tabPinSuggestionCount
    }
    func alreadyPinTabSuggested(domainPath0: String) -> Bool {
        do {
            return try db.alreadyPinTabSuggested(domainPath0: domainPath0)
        } catch {
            Logger.shared.logError("Couldn't save tab pin suggestion for \(domainPath0): \(error)", category: .database)
            return false
        }
    }
    func reset() {
        do {
            try db.cleanTabPinSuggestions()
        } catch {
            Logger.shared.logError("Couldn't reset tab pin suggestion memory: \(error)", category: .database)
        }
    }
}

struct TabPinSuggestionParameters {
    let domainPath0minDayCount: Int
    let minTabReadingTimeShare: Float
    let minAverageTabLifetime: Float
    let minObservationDays: Int
    let candidateRefreshMinInterval: Double
    let maxSuggestionCount: Int
}
private let tabPinSuggestionParameters = TabPinSuggestionParameters(
    domainPath0minDayCount: 4,
    minTabReadingTimeShare: 0.5,
    minAverageTabLifetime: 60, //seconds
    minObservationDays: 14,
    candidateRefreshMinInterval: Double(1 * 60 * 60),
    maxSuggestionCount: 5
)
class TabPinSuggester {
    let storage: DomainPath0TreeStatsStorageProtocol
    let tabPinMemory: TabPinSuggestionMemory
    private var eligibleDomainPaths: [ScoredDomainPath0] = []
    private var lastCandidateRefreshDate: Date = Date.distantPast
    private let parameters: TabPinSuggestionParameters
    private var refreshing = false

    init(storage: DomainPath0TreeStatsStorageProtocol,
         suggestionMemory: TabPinSuggestionMemory = TabPinSuggestionMemory(),
         parameters: TabPinSuggestionParameters = tabPinSuggestionParameters
    ) {
        self.storage = storage
        self.parameters = parameters
        self.tabPinMemory = suggestionMemory
        storage.cleanUp(olderThan: 60, maxRows: 50 * 1000)
        refreshEligibleDomainPaths()
    }

    func hasPinned() {
        Persistence.TabPinSuggestion.hasPinned = true
    }

    private func refreshEligibleDomainPaths() {
        guard BeamDate.now.timeIntervalSince(lastCandidateRefreshDate) >  parameters.candidateRefreshMinInterval,
             !refreshing else { return }
        DispatchQueue.global().async { [self] in
            refreshing = true
            defer { refreshing = false }
            self.eligibleDomainPaths = storage.getPinTabSuggestionCandidates(
                minDayCount: parameters.domainPath0minDayCount,
                minTabReadingTimeShare: parameters.minTabReadingTimeShare,
                minAverageTabLifetime: parameters.minAverageTabLifetime,
                dayRange: parameters.minObservationDays,
                maxRows: 1000)
            lastCandidateRefreshDate = BeamDate.now
        }
    }
    func isEligible(url: URL) -> Bool {
        guard let firstReadDate = storage.domainPath0MinReadDay,
              let domainPath0 = url.domainPath0?.absoluteString else { return false }
        if BeamDate.now.timeIntervalSince(firstReadDate) < Double(parameters.minObservationDays * 24 * 60 * 60) { return false }
        if tabPinMemory.tabPinSuggestionCount >= parameters.maxSuggestionCount { return false }
        refreshEligibleDomainPaths()
        if tabPinMemory.alreadyPinTabSuggested(domainPath0: domainPath0) { return false }
        if url.isSearchEngineResultPage { return false }
        if Persistence.TabPinSuggestion.hasPinned ?? false { return false }
        Logger.shared.logDebug("----------------tab pin suggested domain path0------------", category: .tabPinSuggestion)
        for eligible in eligibleDomainPaths.prefix(10) {
            Logger.shared.logDebug("domainPath0: \(eligible.domainPath0) - score: \(eligible.score)", category: .tabPinSuggestion)
        }
        return eligibleDomainPaths.contains { scoredPath in
            domainPath0.starts(with: scoredPath.domainPath0)
        }
    }

    func hasSuggested(url: URL) {
        guard let domainPath0 = url.domainPath0?.absoluteString else { return }
        tabPinMemory.addTabPinSuggestion(domainPath0: domainPath0)
    }
}
