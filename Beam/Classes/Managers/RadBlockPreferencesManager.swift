//
//  RadBlockPreferencesManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 03/06/2021.
//

import Foundation
import BeamCore

enum SynchronizeInterval: String, CaseIterable {
    case disabled, daily, biWeekly, weekly, monthly

    var name: String { rawValue.prefix(1).capitalized + rawValue.dropFirst() }
    var radBlockInterval: RBSynchronizeInterval {
        switch self {
        case .disabled:
            return RBSynchronizeInterval.disabled
        case .daily:
            return RBSynchronizeInterval.daily
        case .biWeekly:
            return RBSynchronizeInterval.biWeekly
        case .weekly:
            return RBSynchronizeInterval.weekly
        case .monthly:
            return RBSynchronizeInterval.monthly
        }
    }

    static func from(radBlockInterval: RBSynchronizeInterval) -> SynchronizeInterval {
        switch radBlockInterval {
        case .disabled:
            return .disabled
        case .daily:
            return .daily
        case .biWeekly:
            return .biWeekly
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        @unknown default:
            fatalError()
        }
    }
}

class RadBlockPreferencesManager {
    var activatedFiltersGroup: [String] = []

    init() {}

    // MARK: - Synchronization

    var lastSynchronizationDate: String {
        guard let date = FilterManager.default.state.lastSynchronizeDate else { return "" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.doesRelativeDateFormatting = true
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    var synchronizeInterval: SynchronizeInterval {
        get {
            SynchronizeInterval.from(radBlockInterval: FilterManager.State.shared.synchronizeInterval)
        }
        set {
            FilterManager.default.synchronizeAutomatically = true
            FilterManager.default.state.synchronizeInterval = newValue.radBlockInterval
        }
    }

    func synchronizeNow() {
        if !FilterManager.default.isSynchronizing {
            ContentBlockingManager.shared.synchronize()
        }
    }

    // MARK: - Whitelist

    func add(domain: String, completion: @escaping () -> Void) {
        if domain.validUrl().isValid {
            RadBlockDatabase.shared.writeAllowlistEntry(forDomain: domain.validUrl().url) { entry, _ in
                entry.groupNames = FilterManager.State.shared.filterGroups.map({ $0.name })
            } completionHandler: { _, error in
                if let error = error {
                    Logger.shared.logError("Add entry in whitelist error: \(error.localizedDescription)", category: .contentBlocking)
                }
            }
            ContentBlockingManager.shared.synchronize()
            completion()
        } else {
            Logger.shared.logError("Domain: \(domain) is a not valid", category: .contentBlocking)
            completion()
        }
    }

    func remove(entries: [RBAllowlistEntry], completion: @escaping () -> Void) {
        for entry in entries {
            RadBlockDatabase.shared.removeAllowlistEntry(forDomain: entry.domain) { error in
                if let error = error {
                    Logger.shared.logError("Remove entry in whitelist error: \(error.localizedDescription)", category: .contentBlocking)
                }
            }
        }
        ContentBlockingManager.shared.synchronize()
        completion()
    }
}
