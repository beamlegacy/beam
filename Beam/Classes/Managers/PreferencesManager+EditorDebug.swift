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
    static let editorToolbarOverlayOpacityKey = "toolbarOverlayOpacity"

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
    static let journalCardTitleFontSizeKey = "journalCardTitleFontSize"
    static let editorFontSizeHeadingOneKey = "editorFontSizeHeadingOne"
    static let editorFontSizeHeadingTwoKey = "editorFontSizeHeadingTwo"

}

// MARK: - Default Values
extension PreferencesManager {
    // WARNING
    // Be extra carefull when changing values
    //
    static let editorIsCenteredDefault = false
    static let editorLeadingPercentageDefault: CGFloat = 45

    static let editorHeaderTopPaddingDefault: CGFloat = 160
    static let editorJournalTopPaddingDefault: CGFloat = 82
    static let editorCardTopPaddingDefault: CGFloat = 20
    static let editorToolbarOverlayOpacityDefault: CGFloat = 0.4

    static let editorMinWidthDefault: CGFloat = 450
    static let editorMaxWidthDefault: CGFloat = 670
    static let editorParentSpacingDefault: CGFloat = 2
    static let editorChildSpacingDefault: CGFloat = 1

    static let editorHeaderOneSizeDefault: CGFloat = 3
    static let editorHeaderTwoSizeDefault: CGFloat = 2

    static let editorLineHeightHeadingDefault: CGFloat = 1.2
    static let editorLineHeightDefault: CGFloat = 1.3
    static let editorLineHeightMultipleLineDefault: CGFloat = 1.2

    static let editorFontSizeDefault: CGFloat = 14
    static let editorCardTitleFontSizeDefault: CGFloat = 30
    static let journalCardTitleFontSizeDefault: CGFloat = 24
    static let editorFontSizeHeadingOneDefault: CGFloat = 20
    static let editorFontSizeHeadingTwoDefault: CGFloat = 17
}

extension PreferencesManager {
    @UserDefault(key: editorLeadingPercentageKey, defaultValue: editorLeadingPercentageDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorLeadingPercentage: CGFloat
    @UserDefault(key: editorIsCenteredKey, defaultValue: editorIsCenteredDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorIsCentered: Bool

    @UserDefault(key: editorHeaderTopPaddingKey, defaultValue: editorHeaderTopPaddingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorHeaderTopPadding: CGFloat
    @UserDefault(key: editorJournalTopPaddingKey, defaultValue: editorJournalTopPaddingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorJournalTopPadding: CGFloat
    @UserDefault(key: editorCardTopPaddingKey, defaultValue: editorCardTopPaddingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorCardTopPadding: CGFloat
    @UserDefault(key: editorToolbarOverlayOpacityKey, defaultValue: editorToolbarOverlayOpacityDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorToolbarOverlayOpacity: Double

    @UserDefault(key: editorLineHeightHeadingKey, defaultValue: editorLineHeightHeadingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorLineHeightHeading: CGFloat
    @UserDefault(key: editorLineHeightKey, defaultValue: editorLineHeightDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorLineHeight: CGFloat
    @UserDefault(key: editorLineHeightMultipleLineKey, defaultValue: editorLineHeightMultipleLineDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorLineHeightMultipleLine: CGFloat

    @UserDefault(key: editorFontSizeKey, defaultValue: editorFontSizeDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorFontSize: CGFloat
    @UserDefault(key: editorCardTitleFontSizeKey, defaultValue: editorCardTitleFontSizeDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorCardTitleFontSize: CGFloat
    @UserDefault(key: journalCardTitleFontSizeKey, defaultValue: journalCardTitleFontSizeDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var journalCardTitleFontSize: CGFloat
    @UserDefault(key: editorFontSizeHeadingOneKey, defaultValue: editorFontSizeHeadingOneDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorFontSizeHeadingOne: CGFloat
    @UserDefault(key: editorFontSizeHeadingTwoKey, defaultValue: editorFontSizeHeadingTwoDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorFontSizeHeadingTwo: CGFloat

    @UserDefault(key: editorMinWidthKey, defaultValue: editorMinWidthDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorMinWidth: CGFloat
    @UserDefault(key: editorMaxWidthKey, defaultValue: editorMaxWidthDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorMaxWidth: CGFloat

    @UserDefault(key: editorParentSpacingKey, defaultValue: editorParentSpacingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorParentSpacing: CGFloat
    @UserDefault(key: editorChildSpacingKey, defaultValue: editorChildSpacingDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorChildSpacing: CGFloat

    @UserDefault(key: editorHeaderOneSizeKey, defaultValue: editorHeaderOneSizeDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
    static var editorHeaderOneSize: CGFloat
    @UserDefault(key: editorHeaderTwoSizeKey, defaultValue: editorHeaderTwoSizeDefault, suiteName: BeamUserDefaults.editorDebugPreferences.suiteName)
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
