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
        case .custom: return "Other…"
        }
    }

    var rawUrl: URL? {
        let fileManager = FileManager.default
        switch self {
        case .downloads:
            return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        case .documents:
            return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        case .desktop:
            return fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        case .custom:
            guard let securityData = PreferencesManager.customDownloadFolder else { return nil }
            var isStale = false
            return try? URL(resolvingBookmarkData: securityData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        }
    }

    var sandboxAccessibleUrl: URL? {
        let fileManager = FileManager.default
        switch self {
        case .downloads:
            return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        default:
            guard let securityData = PreferencesManager.customDownloadFolder else { return nil }
            var isStale = false
            let url = try? URL(resolvingBookmarkData: securityData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                PreferencesManager.customDownloadFolder = try? url?.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            return url
        }
    }
}

// MARK: - Keys
extension PreferencesManager {
    static let isDefaultBrowserKey = "isDefaultBrowser"
    static let selectedDefaultSearchEngineKey = "selectedDefaultSearchEngine"
    static let searchEngineSuggestionKey = "searchEngineSuggestion"
    static let selectedDownloadFolderKey = "selectedDownloadFolder"
    static let customDownloadFolderKey = "customDownloadFolder"
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
    static var defaultCustomDownloadFolder: Data? = nil
    static let openSafeFileAfterDownloadDefault = true
    static let cmdClickOpenTabDefault = true
    static let newTabWindowMakeActiveDefault = true
    static let cmdNumberSwitchTabsDefault = false
    static let showWebsiteIconTabDefault = true
    static let restoreLastBeamSessionDefault = true
}

extension PreferencesManager {
    static var browserPreferencesContainer = "app_browser_preferences"

    @UserDefault(key: selectedDefaultSearchEngineKey, defaultValue: defaultSearchEngine, suiteName: browserPreferencesContainer)
    static var selectedSearchEngine: Int

    @UserDefault(key: searchEngineSuggestionKey, defaultValue: includeSearchEngineSuggestionDefault, suiteName: browserPreferencesContainer)
    static var includeSearchEngineSuggestion: Bool

    @UserDefault(key: selectedDownloadFolderKey, defaultValue: defaultDownloadFolder, suiteName: browserPreferencesContainer)
    static var selectedDownloadFolder: Int

    @UserDefault(key: customDownloadFolderKey, defaultValue: defaultCustomDownloadFolder, suiteName: browserPreferencesContainer)
    static var customDownloadFolder: Data?

    @UserDefault(key: openSafeFileAfterDownloadKey, defaultValue: openSafeFileAfterDownloadDefault, suiteName: browserPreferencesContainer)
    static var openSafeFileAfterDownload: Bool

    @UserDefault(key: cmdClickOpenTabKey, defaultValue: cmdClickOpenTabDefault, suiteName: browserPreferencesContainer)
    static var cmdClickOpenTab: Bool

    @UserDefault(key: newTabWindowMakeActiveKey, defaultValue: newTabWindowMakeActiveDefault, suiteName: browserPreferencesContainer)
    static var newTabWindowMakeActive: Bool

    @UserDefault(key: cmdNumberSwitchTabsKey, defaultValue: cmdNumberSwitchTabsDefault, suiteName: browserPreferencesContainer)
    static var cmdNumberSwitchTabs: Bool

    @UserDefault(key: showWebsiteIconTabKey, defaultValue: showWebsiteIconTabDefault, suiteName: browserPreferencesContainer)
    static var showWebsiteIconTab: Bool

    @UserDefault(key: restoreLastBeamSessionKey, defaultValue: restoreLastBeamSessionDefault, suiteName: browserPreferencesContainer)
    static var restoreLastBeamSession: Bool
}
