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
    let defaults = UserDefaults.standard

    // MARK: - Global ON/OFF of AdBlocker
    var isfilterGroupsEnabled: Bool {
        get {
            !FilterManager.default.state.isDisabled
        }
        set {
            FilterManager.default.state.isDisabled = !newValue
            if !newValue {
                ContentBlockingManager.shared.removeAllRulesLists()
            } else {
                ContentBlockingManager.shared.synchronize()
            }
        }
    }

    var isAdsFilterEnabled: Bool {
        get {
            defaults.bool(forKey: "adsFilter")
        }
        set {
            if newValue {
                isfilterGroupsEnabled = true
            }
            defaults.setValue(newValue, forKey: "adsFilter")
            ContentBlockingManager.shared.synchronize()
        }
    }

    var isPrivacyFilterEnabled: Bool {
        get {
            defaults.bool(forKey: "privacyFilter")
        }
        set {
            if newValue {
                isfilterGroupsEnabled = true
            }
            defaults.setValue(newValue, forKey: "privacyFilter")
            ContentBlockingManager.shared.synchronize()
        }
    }

    var isSocialMediaFilterEnabled: Bool {
        get {
            FilterManager.default.state.privacyFilterGroup.isSocialMediaFilterEnabled
        }
        set {
            if newValue {
                isfilterGroupsEnabled = true
            }
            FilterManager.default.state.privacyFilterGroup.isSocialMediaFilterEnabled = newValue
            ContentBlockingManager.shared.synchronize()
        }
    }

    var isAnnoyancesFilterEnabled: Bool {
        get {
            defaults.bool(forKey: "annoyanceFilter")
        }
        set {
            if newValue {
                isfilterGroupsEnabled = true
            }
            defaults.set(newValue, forKey: "annoyanceFilter")
            ContentBlockingManager.shared.synchronize()
        }
    }

    var isCookiesFilterEnabled: Bool {
        get {
            FilterManager.default.state.annoyanceFilterGroup.isCookiesFilterEnabled
        }
        set {
            if newValue {
                isfilterGroupsEnabled = true
            }
            FilterManager.default.state.annoyanceFilterGroup.isCookiesFilterEnabled = newValue
            ContentBlockingManager.shared.synchronize()
        }
    }

    var activatedFiltersGroup: [String] = []

    init() {
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
