//
//  PreferencesManager.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 01/07/2021.
//

import Foundation
import Combine

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

}

// MARK: - General Preferences

enum BeamAppearance: Int {
    case dark, light, system
}

// MARK: - Keys
extension PreferencesManager {
    static let beamAppearanceKey = "beamAppearance"
    static let fontMinKey = "fontMin"
    static let fontSizeIndexKey = "fontSizeIndex"
    static let tabToHighlightKey = "tabToHighlight"
    static let autoUpdateKey = "autoUpdate"
    static let dataBackupOnUpdate = "dataBackupOnUpdate"
}

// MARK: - Default Values
extension PreferencesManager {
    static let beamAppearancePreferenceDefault = 2
    static let isFontMinOnPreferenceDefault = false
    static let fontSizeIndexPreferenceDefault = 5
    static let isTabToHighlightOnDefault = false
    static let isAutoUpdateOnDefault = true
    static let isDataBackupOnUpdateOnDefault = true
}

extension PreferencesManager {
    static var generalPreferencesContainer = UserDefaults(suiteName: "app_general_preferences") ?? .standard

    @UserDefault(key: beamAppearanceKey, defaultValue: beamAppearancePreferenceDefault, container: generalPreferencesContainer)
    static var beamAppearancePreference: Int

    @UserDefault(key: fontMinKey, defaultValue: isFontMinOnPreferenceDefault, container: generalPreferencesContainer)
    static var isFontMinOnPreference: Bool

    @UserDefault(key: fontSizeIndexKey, defaultValue: fontSizeIndexPreferenceDefault, container: generalPreferencesContainer)
    static var fontSizeIndexPreference: Int

    @UserDefault(key: tabToHighlightKey, defaultValue: isTabToHighlightOnDefault, container: generalPreferencesContainer)
    static var isTabToHighlightOn: Bool

    @UserDefault(key: autoUpdateKey, defaultValue: isAutoUpdateOnDefault, container: generalPreferencesContainer)
    static var isAutoUpdateOn: Bool

    @UserDefault(key: dataBackupOnUpdate, defaultValue: isDataBackupOnUpdateOnDefault, container: generalPreferencesContainer)
    static var isDataBackupOnUpdateOn: Bool
}
