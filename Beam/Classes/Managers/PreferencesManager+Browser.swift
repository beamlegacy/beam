//
//  PreferencesManager+Browser.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/07/2021.
//

import Foundation

enum SearchEnginesPreferences: Int, CaseIterable, Identifiable {
    case google
    case yahoo
    case duckduckgo
    case bing

    var id: Int { return rawValue}

    var name: String {
        switch self {
        case .google: return "Google"
        case .yahoo: return "Yahoo"
        case .duckduckgo: return "DuckDuckGo"
        case .bing: return "Bing"
        }
    }
}

enum DownloadFolder: Int, CaseIterable, Identifiable {
    case downloads
    case documents
    case desktop
    case custom

    var id: Int { return rawValue}

    var name: String {
        switch self {
        case .downloads: return "Downloads"
        case .documents: return "Documents"
        case .desktop: return "Desktop"
        case .custom: return "Other.."
        }
    }
}

// MARK: - Keys
extension PreferencesManager {
    static let isDefaultBrowserKey = "isDefaultBrowser"
    static let selectedDefaultSearchEngineKey = "selectedDefaultSearchEngine"
    static let searchEngineSuggestionKey = "searchEngineSuggestion"
    static let selectedDownloadFolderKey = "selectedDownloadFolder"
    static let openSafeFileAfterDownloadKey = "openSafeFileAfterDownload"
    static let cmdClickOpenTabKey = "cmdClickOpenTab"
    static let newTabWindowMakeActiveKey = "newTabWindowMakeActive"
    static let cmdNumberSwitchTabsKey = "cmdNumberSwitchTabs"
    static let showWebsiteIconTabKey = "showWebsiteIconTab"
    static let restoreLastBeamSessionKey = "restoreLastBeamSession"
}

// MARK: - Default Values
extension PreferencesManager {
    static let defaultSearchEngine = 0
    static let includeSearchEngineSuggestionDefault = true
    static var defaultDownloadFolder = 0
    static let openSafeFileAfterDownloadDefault = true
    static let cmdClickOpenTabDefault = true
    static let newTabWindowMakeActiveDefault = true
    static let cmdNumberSwitchTabsDefault = false
    static let showWebsiteIconTabDefault = true
    static let restoreLastBeamSessionDefault = true
}

extension PreferencesManager {
    static var browserPreferencesContainer = UserDefaults(suiteName: "app_browser_preferences") ?? .standard

    @UserDefault(key: isDefaultBrowserKey, defaultValue: false, container: browserPreferencesContainer)
    static var isDefaultBrowser: Bool

    @UserDefault(key: selectedDefaultSearchEngineKey, defaultValue: defaultSearchEngine, container: browserPreferencesContainer)
    static var selectedSearchEngine: Int

    @UserDefault(key: searchEngineSuggestionKey, defaultValue: includeSearchEngineSuggestionDefault, container: browserPreferencesContainer)
    static var includeSearchEngineSuggestion: Bool

    @UserDefault(key: selectedDownloadFolderKey, defaultValue: defaultDownloadFolder, container: browserPreferencesContainer)
    static var selectedDownloadFolder: Int

    @UserDefault(key: openSafeFileAfterDownloadKey, defaultValue: openSafeFileAfterDownloadDefault, container: browserPreferencesContainer)
    static var openSafeFileAfterDownload: Bool

    @UserDefault(key: cmdClickOpenTabKey, defaultValue: cmdClickOpenTabDefault, container: browserPreferencesContainer)
    static var cmdClickOpenTab: Bool

    @UserDefault(key: newTabWindowMakeActiveKey, defaultValue: newTabWindowMakeActiveDefault, container: browserPreferencesContainer)
    static var newTabWindowMakeActive: Bool

    @UserDefault(key: cmdNumberSwitchTabsKey, defaultValue: cmdNumberSwitchTabsDefault, container: browserPreferencesContainer)
    static var cmdNumberSwitchTabs: Bool

    @UserDefault(key: showWebsiteIconTabKey, defaultValue: showWebsiteIconTabDefault, container: browserPreferencesContainer)
    static var showWebsiteIconTab: Bool

    @UserDefault(key: restoreLastBeamSessionKey, defaultValue: restoreLastBeamSessionDefault, container: browserPreferencesContainer)
    static var restoreLastBeamSession: Bool
}
