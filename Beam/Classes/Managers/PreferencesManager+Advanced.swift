//
//  PreferencesManager+Developer.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 26/07/2021.
//

import Foundation

// MARK: - Keys
extension PreferencesManager {
    private static let browsingSessionCollectionIsOnKey = "browsingSessionCollectionIsOn"
    private static let showClusteringSettingsMenuKey = "showClusteringSettingsMenuKey"
    private static let showDebugSectionKey = "showDebugSection"
    private static let showOmniboxScoreSectionKey = "showOmnibarScoreSection"
    private static let showPNSKey = "showPNSview"
    private static let PnsJSIsOnKey = "PnsJSIsOn"
    private static let SpaIndexingKey = "SpaIndexing"
    private static let collectFeedbackKey = "collectFeedback"
    private static let showsCollectFeedbackAlertKey = "showsCollectFeedbackAlert"
    private static let enableTabGroupingKey = "enableTabGrouping"
    private static let createJournalOncePerWindowKey = "createJournalOncePerWindow"
    private static let useSidebarKey = "useSidebar"
    private static let includeHistoryContentsInOmniBoxKey = "includeHistoryContentsInOmniBox"
    private static let enableOmnibeamsKey = "enableOmnibeams"
    private static let enableDailySummaryKey = "enableDailySummary"
    private static let enableFallbackReadabilityParserKey = "enableFallbackReadabilityParser"
}

// MARK: - Default Values
extension PreferencesManager {
    #if TEST
    private static let browsingSessionCollectionIsOnDefault = true
    #endif
    private static let browsingSessionCollectionIsOnDefault = false
    private static let showClusteringSettingsMenuDefault = Configuration.branchType == .develop
    private static let showDebugSectionDefault = false
    private static let showOmniboxScoreSectionDefault = false
    private static let showPNSDefault = true
    private static let PnsJSIsOnDefault = true
    private static let collectFeedbackDefault = true
    private static let showsCollectFeedbackAlertDefault = true
    private static let enableTabGroupingDefault = true
    private static let createJournalOncePerWindowDefault = true
    private static let useSidebarDefault = false
    static let includeHistoryContentsInOmniBoxDefault = false
    static let enableOmnibeamsDefault = false
    private static let enableDailySummaryDefault: Bool = Configuration.branchType == .develop
    private static let enableFallbackReadabilityParserDefault: Bool = false
}

extension PreferencesManager {
    @UserDefault(key: browsingSessionCollectionIsOnKey, defaultValue: browsingSessionCollectionIsOnDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var browsingSessionCollectionIsOn: Bool

    @UserDefault(key: showClusteringSettingsMenuKey, defaultValue: showClusteringSettingsMenuDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showClusteringSettingsMenu: Bool

    @UserDefault(key: enableFallbackReadabilityParserKey, defaultValue: enableFallbackReadabilityParserDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var enableFallbackReadabilityParser: Bool

    @UserDefault(key: showDebugSectionKey, defaultValue: showDebugSectionDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showDebugSection: Bool

    @UserDefault(key: showOmniboxScoreSectionKey, defaultValue: showOmniboxScoreSectionDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showOmniboxScoreSection: Bool

    @UserDefault(key: showPNSKey, defaultValue: showPNSDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var showPNSView: Bool

    @UserDefault(key: PnsJSIsOnKey, defaultValue: PnsJSIsOnDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var PnsJSIsOn: Bool

    @UserDefault(key: collectFeedbackKey, defaultValue: collectFeedbackDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var isCollectFeedbackEnabled: Bool

    @UserDefault(key: showsCollectFeedbackAlertKey, defaultValue: showsCollectFeedbackAlertDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showsCollectFeedbackAlert: Bool

    @UserDefault(key: enableTabGroupingKey, defaultValue: enableTabGroupingDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var enableTabGrouping: Bool
    static var enableTabGroupingFeedback: Bool {
        Configuration.branchType == .develop && Configuration.env != .test && enableTabGrouping
    }

    @UserDefault(key: createJournalOncePerWindowKey, defaultValue: createJournalOncePerWindowDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var createJournalOncePerWindow: Bool

    @UserDefault(key: useSidebarKey, defaultValue: useSidebarDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var useSidebar: Bool

    @UserDefault(key: includeHistoryContentsInOmniBoxKey, defaultValue: includeHistoryContentsInOmniBoxDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var includeHistoryContentsInOmniBox: Bool

    @UserDefault(key: enableOmnibeamsKey, defaultValue: enableOmnibeamsDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var enableOmnibeams: Bool

    @UserDefault(key: enableDailySummaryKey, defaultValue: enableDailySummaryDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var enableDailySummary: Bool

}
