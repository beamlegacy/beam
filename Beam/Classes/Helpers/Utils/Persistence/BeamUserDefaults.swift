//
//  BeamUserDefault.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 29/11/2021.
//

import Foundation
import BeamCore

enum BeamUserDefaults: String, CaseIterable {
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
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            Logger.shared.logError("Error creating suiteName for BeamUserDefaults: Can't find bundle identifier", category: .general)
            return self.suiteNameBody + ".\(Configuration.env)"
        }
        return bundleIdentifier + ".\(self.suiteNameBody)" + ".\(Configuration.env)"
    }

    private var suiteNameBody: String {
        self.rawValue.prefix(1).capitalized + self.rawValue.dropFirst()
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
