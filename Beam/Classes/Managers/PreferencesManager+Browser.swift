//
//  PreferencesManager+Browser.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/07/2021.
//

import Foundation

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
    static let showsStatusBarKey = "showsStatusBar"
    static let collectSoundsKey = "collectSounds"
}

// MARK: - Default Values
extension PreferencesManager {
    static let defaultSearchEngine = SearchEngineProvider.google
    static let includeSearchEngineSuggestionDefault = true
    static var defaultDownloadFolder = 0
    static var defaultCustomDownloadFolder: Data? = nil
    static let openSafeFileAfterDownloadDefault = true
    static let cmdClickOpenTabDefault = true
    static let newTabWindowMakeActiveDefault = true
    static let cmdNumberSwitchTabsDefault = false
    static let showWebsiteIconTabDefault = true
    static let restoreLastBeamSessionDefault = false
    static let showsStatusBarDefault = false
    static let collectSoundsDefault = true
}

extension PreferencesManager {
    @UserDefault(key: selectedDefaultSearchEngineKey, defaultValue: defaultSearchEngine.rawValue, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var selectedSearchEngine: String

    @UserDefault(key: searchEngineSuggestionKey, defaultValue: includeSearchEngineSuggestionDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var includeSearchEngineSuggestion: Bool

    @UserDefault(key: selectedDownloadFolderKey, defaultValue: defaultDownloadFolder, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var selectedDownloadFolder: Int

    @UserDefault(key: customDownloadFolderKey, defaultValue: defaultCustomDownloadFolder, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var customDownloadFolder: Data?

    @UserDefault(key: openSafeFileAfterDownloadKey, defaultValue: openSafeFileAfterDownloadDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var openSafeFileAfterDownload: Bool

    @UserDefault(key: cmdClickOpenTabKey, defaultValue: cmdClickOpenTabDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var cmdClickOpenTab: Bool

    @UserDefault(key: newTabWindowMakeActiveKey, defaultValue: newTabWindowMakeActiveDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var newTabWindowMakeActive: Bool

    @UserDefault(key: cmdNumberSwitchTabsKey, defaultValue: cmdNumberSwitchTabsDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var cmdNumberSwitchTabs: Bool

    @UserDefault(key: showWebsiteIconTabKey, defaultValue: showWebsiteIconTabDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showWebsiteIconTab: Bool

    @UserDefault(key: restoreLastBeamSessionKey, defaultValue: restoreLastBeamSessionDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var restoreLastBeamSession: Bool

    @UserDefault(key: showsStatusBarKey, defaultValue: showsStatusBarDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var showsStatusBar: Bool

    @UserDefault(key: collectSoundsKey, defaultValue: collectSoundsDefault, suiteName: BeamUserDefaults.browserPreferences.suiteName)
    static var isCollectSoundsEnabled: Bool

}
