//
//  BeamUserDefault.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/11/2021.
//

import Foundation

enum BeamUserDefaults: CaseIterable {
    case supportedEmbedDomains
    case pinnedBrowserTabs
    case savedClosedTabs
    case generalPreferences
    case browserPreferences
    case cardsPreferences
    case privacyPreferences
    case passwordsPreferences
    case advancedPreferences
    case editorDebugPreferences

    public var suiteName: String {
        self.suiteNamePrefix + "-\(Configuration.env)"
    }

    private var suiteNamePrefix: String {
        switch self {
        case .supportedEmbedDomains: return "SupportedEmbedDomains"
        case .pinnedBrowserTabs: return "PinnedBrowserTabsManager"
        case .savedClosedTabs: return "SavedClosedTabs"
        case .generalPreferences: return "app_general_preferences"
        case .browserPreferences: return "app_browser_preferences"
        case .cardsPreferences: return "app_cards_preferences"
        case .privacyPreferences: return "app_privacy_preferences"
        case .passwordsPreferences: return "app_passwords_preferences"
        case .advancedPreferences: return "app_advanced_preferences"
        case .editorDebugPreferences: return "app_advanced_preferences_editor_debug"
        }
    }
}

class BeamUserDefaultsManager {
    static func clear() {
        BeamUserDefaults.allCases.forEach { beamUserDefault in
            let userDefaultKeys = UserDefaults(suiteName: beamUserDefault.suiteName)?.dictionaryRepresentation().keys
            userDefaultKeys?.forEach({ key in
                UserDefaults(suiteName: beamUserDefault.suiteName)?.removeObject(forKey: key)
            })
        }
    }
}
