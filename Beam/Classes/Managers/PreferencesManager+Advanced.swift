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
    static let showOmniboxScoreSectionKey = "showOmnibarScoreSection"
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
    static let showOmniboxScoreSectionDefault = false
    static let showPNSDefault = true
    static let PnsJSIsOnDefault = true
}

extension PreferencesManager {
    @UserDefault(key: browsingSessionCollectionIsOnKey, defaultValue: browsingSessionCollectionIsOnDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var browsingSessionCollectionIsOn: Bool

    @UserDefault(key: showTabGrougpingMenuItemKey, defaultValue: showTabGrougpingMenuItemDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showTabGrougpingMenuItem: Bool

    @UserDefault(key: showDebugSectionKey, defaultValue: showDebugSectionDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showDebugSection: Bool

    @UserDefault(key: showOmniboxScoreSectionKey, defaultValue: showOmniboxScoreSectionDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showOmniboxScoreSection: Bool

    @UserDefault(key: showPNSKey, defaultValue: showPNSDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showPNSView: Bool

    @UserDefault(key: PnsJSIsOnKey, defaultValue: PnsJSIsOnDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var PnsJSIsOn: Bool
}
