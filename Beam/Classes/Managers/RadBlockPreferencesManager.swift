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

    var name: String { rawValue.capitalizeFirstChar() }
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

    init() {
        if FilterManager.default.synchronizeAutomatically {
            // We disable the automatic sync provided by RadBlock's timer because it used to cause crashes.
            // Instead, we sync if needed when the app becomes active.
            // see https://linear.app/beamapp/issue/BE-4065
            FilterManager.default.synchronizeAutomatically = false
        }
    }

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
            FilterManager.default.synchronizeAutomatically = false
            FilterManager.default.state.synchronizeInterval = newValue.radBlockInterval
        }
    }

    // MARK: - Whitelist

    func add(domain: String) {
        guard let hostname = domain.validUrl().url.hostname else {
            Logger.shared.logError("Domain: \(domain) is a not valid", category: .contentBlocking)
            return
        }

        RadBlockDatabase.shared.writeAllowlistEntry(forDomain: hostname) { entry, _ in
            entry.groupNames = FilterManager.State.shared.filterGroups.map({ $0.name })
        } completionHandler: { _, error in
            if let error = error {
                Logger.shared.logError("Add entry in whitelist error: \(error.localizedDescription)", category: .contentBlocking)
            } else {
                ContentBlockingManager.shared.synchronize()
            }
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
