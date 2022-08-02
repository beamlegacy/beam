//
//  OmniBoxView.swift
//  BeamUITests
//
//  Created by Andrii on 28.07.2021.
//

import Foundation
import XCTest

class OmniBoxTestView: BaseView {
    
    func focusOmniBoxSearchField(forCurrenTab: Bool = false) {
        shortcutHelper.shortcutActionInvoke(action: forCurrenTab ? .openLocation : .newTab)
        _ = getOmniBoxSearchField().waitForExistence(timeout: BaseTest.maximumWaitTimeout)
    }

    func getOmniBoxSearchField() -> XCUIElement {
        return searchField(ToolbarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
    }
    
    @discardableResult
    func typeInOmnibox(_ text: String) -> OmniBoxTestView {
        getOmniBoxSearchField().typeText(text)
        return self
    }

    @discardableResult
    func enterCreateNoteMode() -> OmniBoxTestView {
        getOmniBoxSearchField().typeKey(.enter, modifierFlags: .option)
        _ = getOmniBoxSearchField().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return OmniBoxTestView()
    }
    
    func getAutocompleteResults() -> XCUIElementQuery {
        return app.links.matching(NSPredicate(format: "identifier CONTAINS '\(WebViewLocators.Link.autocompleteResult.accessibilityIdentifier)'"))
    }
    
    func getSelectedAutocompleteElementQuery() -> XCUIElementQuery {
        return getAutocompleteResults().matching(NSPredicate(format: "identifier CONTAINS '-selected'"))
    }
    
    func getCreateNoteAutocompleteElementQuery() -> XCUIElementQuery {
        return getAutocompleteResults().matching(NSPredicate(format: "identifier CONTAINS '-createNote'"))
    }
    
    func getNoteAutocompleteElementQuery() -> XCUIElementQuery {
        return getAutocompleteResults().matching(NSPredicate(format: "identifier CONTAINS '-note'"))
    }
    
    func getSearchFieldValue() -> String {
        return getOmniBoxSearchField().getStringValue()
    }
    
    func waitForSearchFieldValueToEqual(expectedValue: String) -> Bool {
        return BaseTest.waitForStringValueEqual(expectedValue, getOmniBoxSearchField())
    }
    
    @discardableResult
    func clearOmniboxViaXbutton() -> XCUIElement {
        button(OmniboxViewLocators.Buttons.searchFieldClearButton.accessibilityIdentifier).clickOnExistence()
        return getOmniBoxSearchField()
    }
    
    func clickBackButton() {
        button(ToolbarLocators.Buttons.backButton.accessibilityIdentifier).clickOnExistence()
    }
    
    func clickForwardButton() {
        button(ToolbarLocators.Buttons.forwardButton.accessibilityIdentifier).clickOnExistence()
    }
    
    @discardableResult
    func navigateToJournalViaHomeButton() -> JournalTestView {
        button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).clickOnExistence()
        return JournalTestView()
    }
    
    @discardableResult
    func navigateToNoteViaPivotButton() -> NoteTestView {
        button(ToolbarLocators.Buttons.openNoteButton.accessibilityIdentifier).clickOnExistence()
        return NoteTestView()
    }
    
    @discardableResult
    func navigateToWebView()  -> WebTestView {
        button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }
    
    @discardableResult
    func openDownloadsView() -> DownloadTestView {
        let downloadViewButton = button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier)
        _ = downloadViewButton.waitForExistence(timeout: BaseTest.implicitWaitTimeout)
        waitFor(PredicateFormat.isHittable.rawValue, downloadViewButton, BaseTest.minimumWaitTimeout)
        downloadViewButton.tapInTheMiddle()
        return DownloadTestView()
    }
    
    func waitForAutocompleteResultsLoad(timeout: TimeInterval, expectedNumber: Int) -> Bool {
        // wait for first result to be displayed
        _ = getAutocompleteResults().firstMatch.waitForExistence(timeout: timeout)
        return getAutocompleteResults().count == expectedNumber
    }
    
    func isOmniboxFocused() -> Bool {
        return inputHasFocus(getOmniBoxSearchField())
    }
    
    func doesOmniboxCreateNoteExist() -> Bool {
        return link(OmniboxLocators.Labels.createNote.accessibilityIdentifier).exists
    }
    
    func doesOmniboxAllNotesExist() -> Bool {
        return getAutocompleteResults().matching(NSPredicate(format: "label == '\(OmniboxLocators.Labels.action.accessibilityIdentifier)' && value == '\(OmniboxLocators.Labels.allNotes.accessibilityIdentifier)'")).firstMatch.exists
    }
    
    func getAutocompleteIdentifierFor(domainURL: String) -> String {
        return "autocompleteResult-selected-" + domainURL
    }
    
    func getAutocompleteURLIdentifierFor(domainURL: String) -> String {
        return getAutocompleteIdentifierFor(domainURL: domainURL) + "-url"
    }
}
