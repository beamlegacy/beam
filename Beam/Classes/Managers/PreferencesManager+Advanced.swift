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
    private static let showTabGrougpingMenuItemKey = "showTabGrougpingMenuItem"
    private static let showDebugSectionKey = "showDebugSection"
    private static let showOmniboxScoreSectionKey = "showOmnibarScoreSection"
    private static let showPNSKey = "showPNSview"
    private static let PnsJSIsOnKey = "PnsJSIsOn"
    private static let SpaIndexingKey = "SpaIndexing"
    private static let collectFeedbackKey = "collectFeedback"
    private static let showsCollectFeedbackAlertKey = "showsCollectFeedbackAlert"
    private static let showTabsColoringKey = "showTabsColoring"
    private static let showWebOnLaunchIfTabsKey = "showWebOnLaunchIfTabs"
    private static let createJournalOncePerWindowKey = "createJournalOncePerWindow"
    private static let includeHistoryContentsInOmniBoxKey = "includeHistoryContentsInOmniBox"
    private static let enableDailySummaryKey = "enableDailySummary"
}

// MARK: - Default Values
extension PreferencesManager {
    #if TEST
    private static let browsingSessionCollectionIsOnDefault = true
    #endif
    private static let browsingSessionCollectionIsOnDefault = false
    private static let showTabGrougpingMenuItemDefault = Configuration.branchType == .develop
    private static let showDebugSectionDefault = false
    private static let showOmniboxScoreSectionDefault = false
    private static let showPNSDefault = true
    private static let PnsJSIsOnDefault = true
    private static let collectFeedbackDefault = true
    private static let showsCollectFeedbackAlertDefault = true
    private static let showTabsColoringDefault = Configuration.branchType == .develop
    private static let showWebOnLaunchIfTabsDefault = true
    private static let createJournalOncePerWindowDefault = true
    static let includeHistoryContentsInOmniBoxDefault = false
    private static let enableDailySummaryDefault: Bool = Configuration.branchType == .develop
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

    @UserDefault(key: collectFeedbackKey, defaultValue: collectFeedbackDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var isCollectFeedbackEnabled: Bool

    @UserDefault(key: showsCollectFeedbackAlertKey, defaultValue: showsCollectFeedbackAlertDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showsCollectFeedbackAlert: Bool

    @UserDefault(key: showTabsColoringKey, defaultValue: showTabsColoringDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showTabsColoring: Bool

    @UserDefault(key: showWebOnLaunchIfTabsKey, defaultValue: showWebOnLaunchIfTabsDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showWebOnLaunchIfTabs: Bool

    @UserDefault(key: createJournalOncePerWindowKey, defaultValue: createJournalOncePerWindowDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var createJournalOncePerWindow: Bool

    @UserDefault(key: includeHistoryContentsInOmniBoxKey, defaultValue: includeHistoryContentsInOmniBoxDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var includeHistoryContentsInOmniBox: Bool

    @UserDefault(key: enableDailySummaryKey, defaultValue: enableDailySummaryDefault, suiteName: BeamUserDefaults.advancedPreferences.suiteName)
    static var enableDailySummary: Bool

}
