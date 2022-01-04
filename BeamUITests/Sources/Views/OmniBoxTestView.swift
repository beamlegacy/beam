//
//  OmniBoxView.swift
//  BeamUITests
//
//  Created by Andrii on 28.07.2021.
//

import Foundation
import XCTest

class OmniBoxTestView: BaseView {


    func focusOmniBoxSearchField() {
        shortcutsHelper.shortcutActionInvoke(action: .openLocation)
    }

    func getOmniBoxSearchField() -> XCUIElement {
        return searchField(ToolbarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
    }
    
    func getAutocompleteResults() -> XCUIElementQuery {
        return app.otherElements.matching(NSPredicate(format: "identifier CONTAINS '\(WebViewLocators.Other.autocompleteResult.accessibilityIdentifier)'"))
    }
    
    func getSearchFieldValue() -> String {
        return self.getElementStringValue(element: getOmniBoxSearchField())
    }
    
    func clickBackButton() {
        button(ToolbarLocators.Buttons.backButton.accessibilityIdentifier).click()
    }
    
    func clickForwardButton() {
        button(ToolbarLocators.Buttons.forwardButton.accessibilityIdentifier).click()
    }
    
    @discardableResult
    func navigateToJournalViaHomeButton() -> JournalTestView {
        button(ToolbarLocators.Buttons.homeButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
    
    @discardableResult
    func navigateToCardViaPivotButton() -> CardTestView {
        button(ToolbarLocators.Buttons.openCardButton.accessibilityIdentifier).click()
        return CardTestView()
    }
    
    @discardableResult
    func navigateToWebView()  -> WebTestView {
        button(ToolbarLocators.Buttons.openWebButton.accessibilityIdentifier).click()
        return WebTestView()
    }
    
    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }
    
    @discardableResult
    func openDownloadsView() -> DownloadTestView {
        let downloadViewButton = button(ToolbarLocators.Buttons.downloadsButton.accessibilityIdentifier)
        _ = downloadViewButton.waitForExistence(timeout: minimumWaitTimeout)
        WaitHelper().waitFor(WaitHelper.PredicateFormat.isHittable.rawValue, downloadViewButton, minimumWaitTimeout)
        downloadViewButton.tapInTheMiddle()
        if !staticText(DownloadViewLocators.Labels.downloadsLabel.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) {
            downloadViewButton.tapInTheMiddle()
        }
        return DownloadTestView()
    }
    
    func waitForAutocompleteResultsLoad(timeout: TimeInterval, expectedNumber: Int) -> Bool {
        var count: TimeInterval = 0
        while getAutocompleteResults().count != expectedNumber && count < timeout {
            sleep(1)
            count += 1
        }
        return count < timeout
    }
}
