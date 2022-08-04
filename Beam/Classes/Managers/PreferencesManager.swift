//
//  PreferencesManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/07/2021.
//

import Foundation
import Combine
import SwiftUI

class PreferencesManager {
    static let contentWidth = 726.0
    static let shared: PreferencesManager = PreferencesManager()
    var scope = Set<AnyCancellable>()

    @Published var beamAppearance: BeamAppearance = .system
    var fontSizes = 8..<22

    init() {
        beamAppearance = BeamAppearance(rawValue: PreferencesManager.beamAppearancePreference) ?? .system

        $beamAppearance.sink { newValue in
            AppDelegate.main.setAppearance(newValue)
            PreferencesManager.beamAppearancePreference = newValue.rawValue
        }.store(in: &scope)

        PreferencesManager.$isAdsFilterEnabled.sink { newValue in
            PreferencesManager.filterChanged(enabled: newValue)
        }.store(in: &scope)

        PreferencesManager.$isPrivacyFilterEnabled.sink { newValue in
            PreferencesManager.filterChanged(enabled: newValue)
        }.store(in: &scope)

        PreferencesManager.$isAnnoyancesFilterEnabled.sink { newValue in
            PreferencesManager.filterChanged(enabled: newValue)
        }.store(in: &scope)
    }

    static internal func filterChanged(enabled: Bool) {
        if enabled {
            PreferencesManager.isfilterGroupsEnabled = true
        }
        ContentBlockingManager.shared.synchronize()
    }

    static func openLink(url: URL?) {
        if let url = url, let state = AppDelegate.main.windows.first?.state {
            state.mode = .web
            _ = state.createTab(withURLRequest: URLRequest(url: url), originalQuery: nil)
        }
    }
}

// MARK: - General Preferences

enum BeamAppearance: Int {
    case dark, light, system
}

// MARK: - Keys
private extension PreferencesManager {
    static let beamAppearanceKey = "beamAppearance"
    static let fontMinKey = "fontMin"
    static let fontSizeIndexKey = "fontSizeIndex"
    static let tabToHighlightKey = "tabToHighlight"
    static let isHapticFeedbackOnKey = "isHapticFeedbackOn"
    static let autoUpdateKey = "autoUpdate"
    static let dataBackupOnUpdate = "dataBackupOnUpdate"
    static let defaultWindowModeKey = "defaultWindowMode"
}

// MARK: - Default Values
private extension PreferencesManager {
    static let beamAppearancePreferenceDefault = 2
    static let isFontMinOnPreferenceDefault = false
    static let fontSizeIndexPreferenceDefault = 5
    static let isTabToHighlightOnDefault = false
    static let isHapticFeedbackOnDefault = true
    static let isAutoUpdateOnDefault = true
    static let isDataBackupOnUpdateOnDefault = true
    static let defaultWindowModeDefault = PreferencesDefaultWindowMode.journal
}

extension PreferencesManager {
    @UserDefault(key: beamAppearanceKey, defaultValue: beamAppearancePreferenceDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var beamAppearancePreference: Int

    @UserDefault(key: fontMinKey, defaultValue: isFontMinOnPreferenceDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var isFontMinOnPreference: Bool

    @UserDefault(key: fontSizeIndexKey, defaultValue: fontSizeIndexPreferenceDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var fontSizeIndexPreference: Int

    @UserDefault(key: tabToHighlightKey, defaultValue: isTabToHighlightOnDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var isTabToHighlightOn: Bool

    @UserDefault(key: isHapticFeedbackOnKey, defaultValue: isHapticFeedbackOnDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var isHapticFeedbackOn: Bool

    @UserDefault(key: autoUpdateKey, defaultValue: isAutoUpdateOnDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var isAutoUpdateOn: Bool

    @UserDefault(key: dataBackupOnUpdate, defaultValue: isDataBackupOnUpdateOnDefault, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    static var isDataBackupOnUpdateOn: Bool

    @UserDefault(key: defaultWindowModeKey, defaultValue: defaultWindowModeDefault.rawValue, suiteName: BeamUserDefaults.generalPreferences.suiteName)
    private static var defaultWindowModeValue: Int
    static var defaultWindowMode: PreferencesDefaultWindowMode {
        get { .init(rawValue: defaultWindowModeValue) ?? defaultWindowModeDefault }
        set { defaultWindowModeValue = newValue.rawValue }
    }

    static var isWindowsRestorationEnabled: Bool {
        // NSQuitAlwaysKeepsWindows matches the following system setting:
        // System Preferences > General > Close windows when quitting an app
        return UserDefaults.standard.bool(forKey: "NSQuitAlwaysKeepsWindows")
    }

    static var isWindowsRestorationPrevented: Bool {
        return UserDefaults.standard.bool(forKey: "WindowsRestorationPrevented")
    }
}

extension PreferencesManager {
    enum PreferencesDefaultWindowMode: Int, CaseIterable, Identifiable {
        case journal
        case webTabs

        var id: Int { rawValue }

        var description: LocalizedStringKey {
            switch self {
            case .journal: return "Journal"
            case .webTabs: return "Web Tabs"
            }
        }
    }
}
