//
//  PreferencesManager+Cards.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 02/07/2021.
//

import Foundation
enum PreferencesEmbedOptions: Int, CaseIterable, Identifiable {
    case always
    case only
    case never

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .always:
            return "Always embed"
        case .only:
            return "Only embed when collecting"
        case .never:
            return "Never embed"
        }
    }
}

// MARK: - Keys
extension PreferencesManager {
    static let checkSpellingIsOnKey = "checkSpellingIsOn"
    static let checkGrammarIsOnKey = "checkGrammarIsOn"
    static let correctSpellingIsOnKey = "correctSpellingIsOn"
    static let embedContentPreferenceKey = "embedContentPreference"
    static let alwaysShowBulletsKey = "alwaysShowBullets"
}

// MARK: - Default Values
extension PreferencesManager {
    static let checkSpellingIsOnDefault = true
    static let checkGrammarIsOnDefault = true
    static let correctSpellingIsOnDefault = true
    static let embedContentPreferenceDefault = 0
    static let alwaysShowBulletsDefault = false
}

extension PreferencesManager {
    @UserDefault(key: checkSpellingIsOnKey, defaultValue: checkSpellingIsOnDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var checkSpellingIsOn: Bool

    @UserDefault(key: checkGrammarIsOnKey, defaultValue: checkGrammarIsOnDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var checkGrammarIsOn: Bool

    @UserDefault(key: correctSpellingIsOnKey, defaultValue: correctSpellingIsOnDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var correctSpellingIsOn: Bool

    @UserDefault(key: embedContentPreferenceKey, defaultValue: embedContentPreferenceDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var embedContentPreference: Int

    @UserDefault(key: alwaysShowBulletsKey, defaultValue: alwaysShowBulletsDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var alwaysShowBullets: Bool
}
