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

    static let editorHeaderOneSizeKey = "editorHeaderOneSizeKey"
    static let editorHeaderTwoSizeKey = "editorHeaderTwoSizeKey"

    static let editorLineHeightHeadingKey = "editorLineHeightHeading"
    static let editorLineHeightKey = "editorLineHeight"
    static let editorLineHeightMultipleLineKey = "editorLineHeightMultipleLine"

    static let editorFontSizeKey = "editorFontSize"
    static let editorCardTitleFontSizeKey = "editorCardTitleFontSize"
    static let editorFontSizeHeadingOneKey = "editorFontSizeHeadingOne"
    static let editorFontSizeHeadingTwoKey = "editorFontSizeHeadingTwo"

}

// MARK: - Default Values
extension PreferencesManager {
    static let editorIsCenteredDefault = false
    static let editorLeadingPercentageDefault: CGFloat = 45

    static let editorHeaderTopPaddingDefault: CGFloat = 160
    static let editorJournalTopPaddingDefault: CGFloat = 145
    static let editorCardTopPaddingDefault: CGFloat = 20

    static let editorMinWidthDefault: CGFloat = 450
    static let editorMaxWidthDefault: CGFloat = 670
    static let editorParentSpacingDefault: CGFloat = 2
    static let editorChildSpacingDefault: CGFloat = 0

    static let editorHeaderOneSizeDefault: CGFloat = 2
    static let editorHeaderTwoSizeDefault: CGFloat = 2

    static let editorLineHeightHeadingDefault: CGFloat = 1.2
    static let editorLineHeightDefault: CGFloat = 1.3
    static let editorLineHeightMultipleLineDefault: CGFloat = 1.2

    static let editorFontSizeDefault: CGFloat = 14
    static let editorCardTitleFontSizeDefault: CGFloat = 30
    static let editorFontSizeHeadingOneDefault: CGFloat = 20
    static let editorFontSizeHeadingTwoDefault: CGFloat = 17
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
    @UserDefault(key: editorCardTitleFontSizeKey, defaultValue: editorCardTitleFontSizeDefault, container: editorDebugPreferencesContainer)
    static var editorCardTitleFontSize: CGFloat
    @UserDefault(key: editorFontSizeHeadingOneKey, defaultValue: editorFontSizeHeadingOneDefault, container: editorDebugPreferencesContainer)
    static var editorFontSizeHeadingOne: CGFloat
    @UserDefault(key: editorFontSizeHeadingTwoKey, defaultValue: editorFontSizeHeadingTwoDefault, container: editorDebugPreferencesContainer)
    static var editorFontSizeHeadingTwo: CGFloat

    @UserDefault(key: editorMinWidthKey, defaultValue: editorMinWidthDefault, container: editorDebugPreferencesContainer)
    static var editorMinWidth: CGFloat
    @UserDefault(key: editorMaxWidthKey, defaultValue: editorMaxWidthDefault, container: editorDebugPreferencesContainer)
    static var editorMaxWidth: CGFloat

    @UserDefault(key: editorParentSpacingKey, defaultValue: editorParentSpacingDefault, container: editorDebugPreferencesContainer)
    static var editorParentSpacing: CGFloat
    @UserDefault(key: editorChildSpacingKey, defaultValue: editorChildSpacingDefault, container: editorDebugPreferencesContainer)
    static var editorChildSpacing: CGFloat

    @UserDefault(key: editorHeaderOneSizeKey, defaultValue: editorHeaderOneSizeDefault, container: editorDebugPreferencesContainer)
    static var editorHeaderOneSize: CGFloat
    @UserDefault(key: editorHeaderTwoSizeKey, defaultValue: editorHeaderTwoSizeDefault, container: editorDebugPreferencesContainer)
    static var editorHeaderTwoSize: CGFloat

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
        editorCardTitleFontSize = editorCardTitleFontSizeDefault
        editorFontSizeHeadingOne = editorFontSizeHeadingOneDefault
        editorFontSizeHeadingTwo = editorFontSizeHeadingTwoDefault
        editorMinWidth = editorMinWidthDefault
        editorMaxWidth = editorMaxWidthDefault
        editorParentSpacing = editorParentSpacingDefault
        editorChildSpacing = editorChildSpacingDefault
        editorHeaderOneSize = editorHeaderOneSizeDefault
        editorHeaderTwoSize = editorHeaderTwoSizeDefault
    }
}
