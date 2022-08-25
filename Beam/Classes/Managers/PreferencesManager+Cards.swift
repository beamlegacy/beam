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
            return "Always"
        case .only:
            return "Only embed when capturing"
        case .never:
            return "Never"
        }
    }
}

// MARK: - Keys
extension PreferencesManager {
    static let checkSpellingIsOnKey: String = "checkSpellingIsOn"
    static let checkGrammarIsOnKey: String = "checkGrammarIsOn"
    static let correctSpellingIsOnKey: String = "correctSpellingIsOn"
    static let embedContentPreferenceKey: String = "embedContentPreference"
    static let alwaysShowBulletsKey: String = "alwaysShowBullets"
    static let cursorColorKey: String = "cursorColorKey"
}

// MARK: - Default Values
extension PreferencesManager {
    static let checkSpellingIsOnDefault: Bool = true
    static let checkGrammarIsOnDefault: Bool = true
    static let correctSpellingIsOnDefault: Bool = true
    static let embedContentPreferenceDefault: Int = 1
    static let alwaysShowBulletsDefault: Bool = true
    static let cursorColorDefault: String = BeamColor.Cursor.default.rawValue
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

    @UserDefault(key: cursorColorKey, defaultValue: cursorColorDefault, suiteName: BeamUserDefaults.cardsPreferences.suiteName)
    static var cursorColor: String
}
