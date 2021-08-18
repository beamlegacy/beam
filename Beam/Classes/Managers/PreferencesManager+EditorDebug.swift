//
//  PreferencesManager+EditorDebug.swift
//  Beam
//
//  Created by Jean-Louis Darmon on 06/08/2021.
//

import Foundation

// MARK: - Keys
extension PreferencesManager {
    static let editorLeadingPercentageKey = "leadingPercentage"
    static let editorIsCenteredKey = "editorIsCentered"
    static let editorHeaderTopPaddingKey = "editorHeaderTopPadding"
    static let editorJournalTopPaddingKey = "journalTopPadding"
    static let editorCardTopPaddingKey = "cardTopPadding"
    static let editorMinWidthKey = "editorMinWidth"
    static let editorMaxWidthKey = "editorMaxWidth"
    static let editorParentSpacingKey = "editorParentSpacing"
    static let editorChildSpacingKey = "editorChildSpacing"
    static let editorLineHeightHeadingKey = "editorLineHeightHeading"
    static let editorLineHeightKey = "editorLineHeight"
    static let editorLineHeightMultipleLineKey = "editorLineHeightMultipleLine"
    static let editorFontSizeKey = "editorFontSize"
    static let editorFontSizeHeadingOneKey = "editorFontSizeHeadingOne"
    static let editorFontSizeHeadingTwoKey = "editorFontSizeHeadingTwo"

}

// MARK: - Default Values
extension PreferencesManager {
    static let editorLeadingPercentageDefault: CGFloat = 48.7
    static let editorIsCenteredDefault = false
    static let editorHeaderTopPaddingDefault: CGFloat = 120
    static let editorJournalTopPaddingDefault: CGFloat = 135
    static let editorCardTopPaddingDefault: CGFloat = 0
    static let editorMinWidthDefault = 500
    static let editorMaxWidthDefault = 700
    static let editorParentSpacingDefault: CGFloat = 8
    static let editorChildSpacingDefault: CGFloat = 2
    static let editorLineHeightHeadingDefault: CGFloat = 1.2
    static let editorLineHeightDefault: CGFloat = 1.3
    static let editorLineHeightMultipleLineDefault: CGFloat = 1.1
    static let editorFontSizeDefault: CGFloat = 15
    static let editorFontSizeHeadingOneDefault: CGFloat = 21
    static let editorFontSizeHeadingTwoDefault: CGFloat = 18
}

extension PreferencesManager {
    static var editorDebugPreferencesContainer = UserDefaults(suiteName: "app_advanced_preferences_editor_debug") ?? .standard

    @UserDefault(key: editorLeadingPercentageKey, defaultValue: editorLeadingPercentageDefault, container: editorDebugPreferencesContainer)
    static var editorLeadingPercentage: CGFloat

    @UserDefault(key: editorIsCenteredKey, defaultValue: editorIsCenteredDefault, container: editorDebugPreferencesContainer)
    static var editorIsCentered: Bool

    @UserDefault(key: editorHeaderTopPaddingKey, defaultValue: editorHeaderTopPaddingDefault, container: editorDebugPreferencesContainer)
    static var editorHeaderTopPadding: CGFloat

    @UserDefault(key: editorJournalTopPaddingKey, defaultValue: editorJournalTopPaddingDefault, container: editorDebugPreferencesContainer)
    static var editorJournalTopPadding: CGFloat

    @UserDefault(key: editorCardTopPaddingKey, defaultValue: editorCardTopPaddingDefault, container: editorDebugPreferencesContainer)
    static var editorCardTopPadding: CGFloat

    @UserDefault(key: editorLineHeightHeadingKey, defaultValue: editorLineHeightHeadingDefault, container: editorDebugPreferencesContainer)
    static var editorLineHeightHeading: CGFloat

    @UserDefault(key: editorLineHeightKey, defaultValue: editorLineHeightDefault, container: editorDebugPreferencesContainer)
    static var editorLineHeight: CGFloat

    @UserDefault(key: editorLineHeightMultipleLineKey, defaultValue: editorLineHeightMultipleLineDefault, container: editorDebugPreferencesContainer)
    static var editorLineHeightMultipleLine: CGFloat

    @UserDefault(key: editorFontSizeKey, defaultValue: editorFontSizeDefault, container: editorDebugPreferencesContainer)
    static var editorFontSize: CGFloat

    @UserDefault(key: editorFontSizeHeadingOneKey, defaultValue: editorFontSizeHeadingOneDefault, container: editorDebugPreferencesContainer)
    static var editorFontSizeHeadingOne: CGFloat

    @UserDefault(key: editorFontSizeHeadingTwoKey, defaultValue: editorFontSizeHeadingTwoDefault, container: editorDebugPreferencesContainer)
    static var editorFontSizeHeadingTwo: CGFloat

    @UserDefault(key: editorMinWidthKey, defaultValue: editorMinWidthDefault, container: editorDebugPreferencesContainer)
    static var editorMinWidth: Int

    @UserDefault(key: editorMaxWidthKey, defaultValue: editorMaxWidthDefault, container: editorDebugPreferencesContainer)
    static var editorMaxWidth: Int

    @UserDefault(key: editorParentSpacingKey, defaultValue: editorParentSpacingDefault, container: editorDebugPreferencesContainer)
    static var editorParentSpacing: CGFloat

    @UserDefault(key: editorChildSpacingKey, defaultValue: editorChildSpacingDefault, container: editorDebugPreferencesContainer)
    static var editorChildSpacing: CGFloat

    static func resetDefaultValuesForEditorDebug() {
        editorIsCentered = editorIsCenteredDefault
        editorLeadingPercentage = editorLeadingPercentageDefault
        editorHeaderTopPadding = editorHeaderTopPaddingDefault
        editorJournalTopPadding = editorJournalTopPaddingDefault
        editorCardTopPadding = editorCardTopPaddingDefault
        editorLineHeightHeading = editorLineHeightHeadingDefault
        editorLineHeight = editorLineHeightDefault
        editorLineHeightMultipleLine = editorLineHeightMultipleLineDefault
        editorFontSize = editorFontSizeDefault
        editorFontSizeHeadingOne = editorFontSizeHeadingOneDefault
        editorFontSizeHeadingTwo = editorFontSizeHeadingTwoDefault
        editorMinWidth = editorMinWidthDefault
        editorMaxWidth = editorMaxWidthDefault
        editorParentSpacing = editorParentSpacingDefault
        editorChildSpacing = editorChildSpacingDefault
    }
}
