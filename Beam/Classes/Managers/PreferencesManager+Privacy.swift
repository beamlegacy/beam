//
//  PreferencesManager+Privacy.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 13/07/2021.
//

import Foundation

// MARK: - Keys
extension PreferencesManager {
    static let adsFilterKey = "adsFilter"
    static let privacyFilterKey = "privacyFilter"
    static let annoyanceFilterKey = "annoyanceFilter"
}

// MARK: - Default Values
extension PreferencesManager {
    static let adsFilterDefault = true
    static let privacyFilterDefault = true
    static let annoyanceFilterDefault = true
}

extension PreferencesManager {
    static var privacyPreferencesContainer = UserDefaults(suiteName: "app_privacy_preferences") ?? .standard

    // MARK: - Global ON/OFF of AdBlocker
    static var isfilterGroupsEnabled: Bool {
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

    @UserDefault(key: adsFilterKey, defaultValue: adsFilterDefault, container: privacyPreferencesContainer)
    static var isAdsFilterEnabled: Bool

    @UserDefault(key: privacyFilterKey, defaultValue: privacyFilterDefault, container: privacyPreferencesContainer)
    static var isPrivacyFilterEnabled: Bool

    @UserDefault(key: annoyanceFilterKey, defaultValue: annoyanceFilterDefault, container: privacyPreferencesContainer)
    static var isAnnoyancesFilterEnabled: Bool

    static var isSocialMediaFilterEnabled: Bool {
        get {
            FilterManager.default.state.privacyFilterGroup.isSocialMediaFilterEnabled
        }
        set {
            FilterManager.default.state.privacyFilterGroup.isSocialMediaFilterEnabled = newValue
            PreferencesManager.filterChanged(enabled: newValue)
        }
    }

    static var isCookiesFilterEnabled: Bool {
        get {
            FilterManager.default.state.annoyanceFilterGroup.isCookiesFilterEnabled
        }
        set {
            FilterManager.default.state.annoyanceFilterGroup.isCookiesFilterEnabled = newValue
            PreferencesManager.filterChanged(enabled: newValue)
        }
    }
}
