//
//  PreferencesManager+Developer.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/07/2021.
//

import Foundation

// MARK: - Keys
extension PreferencesManager {
    static let browsingSessionCollectionIsOnKey = "browsingSessionCollectionIsOn"
    static let showTabGrougpingMenuItemKey = "showTabGrougpingMenuItem"
    static let showDebugSectionKey = "showDebugSection"
    static let showOmnibarScoreSectionKey = "showOmnibarScoreSection"
    static let showPNSKey = "showPNSview"
    static let PnsJSIsOnKey = "PnsJSIsOn"
    static let SpaIndexingKey = "SpaIndexing"
}

// MARK: - Default Values
extension PreferencesManager {
    #if TEST
    static let browsingSessionCollectionIsOnDefault = true
    #endif
    static let browsingSessionCollectionIsOnDefault = false
    static let showTabGrougpingMenuItemDefault = false
    static let showDebugSectionDefault = false
    static let showOmnibarScoreSectionDefault = false
    static let showPNSDefault = true
    static let PnsJSIsOnDefault = true
    static let spaIndexingDefault = false
}

extension PreferencesManager {
    static var advancedPreferencesContainer = UserDefaults(suiteName: "app_advanced_preferences") ?? .standard

    @UserDefault(key: browsingSessionCollectionIsOnKey, defaultValue: browsingSessionCollectionIsOnDefault, container: advancedPreferencesContainer)
    static var browsingSessionCollectionIsOn: Bool

    @UserDefault(key: showTabGrougpingMenuItemKey, defaultValue: showTabGrougpingMenuItemDefault, container: advancedPreferencesContainer)
    static var showTabGrougpingMenuItem: Bool

    @UserDefault(key: showDebugSectionKey, defaultValue: showDebugSectionDefault, container: advancedPreferencesContainer)
    static var showDebugSection: Bool

    @UserDefault(key: showOmnibarScoreSectionKey, defaultValue: showOmnibarScoreSectionDefault, container: advancedPreferencesContainer)
    static var showOmnibarScoreSection: Bool

    @UserDefault(key: showPNSKey, defaultValue: showPNSDefault, container: advancedPreferencesContainer)
    static var showPNSView: Bool

    @UserDefault(key: PnsJSIsOnKey, defaultValue: PnsJSIsOnDefault, container: advancedPreferencesContainer)
    static var PnsJSIsOn: Bool

    @UserDefault(key: SpaIndexingKey, defaultValue: spaIndexingDefault, container: advancedPreferencesContainer)
    static var enableSpaIndexing: Bool
}
