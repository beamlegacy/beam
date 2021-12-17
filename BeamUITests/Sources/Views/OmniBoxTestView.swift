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
        return searchField(OmniBoxLocators.SearchFields.omniSearchField.accessibilityIdentifier)
    }
    
    func getAutocompleteResults() -> XCUIElementQuery {
        return app.otherElements.matching(NSPredicate(format: "identifier CONTAINS '\(WebViewLocators.Other.autocompleteResult.accessibilityIdentifier)'"))
    }
    
    func getSearchFieldValue() -> String {
        return self.getElementStringValue(element: getOmniBoxSearchField())
    }
    
    func clickBackButton() {
        button(OmniBoxLocators.Buttons.backButton.accessibilityIdentifier).click()
    }
    
    func clickForwardButton() {
        button(OmniBoxLocators.Buttons.forwardButton.accessibilityIdentifier).click()
    }
    
    @discardableResult
    func navigateToJournalViaHomeButton() -> JournalTestView {
        button(OmniBoxLocators.Buttons.homeButton.accessibilityIdentifier).click()
        return JournalTestView()
    }
    
    @discardableResult
    func navigateToCardViaPivotButton() -> CardTestView {
        button(OmniBoxLocators.Buttons.openCardButton.accessibilityIdentifier).click()
        return CardTestView()
    }
    
    @discardableResult
    func navigateToWebView()  -> WebTestView {
        button(OmniBoxLocators.Buttons.openWebButton.accessibilityIdentifier).click()
        return WebTestView()
    }
    
    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }
    
    @discardableResult
    func openDownloadsView() -> DownloadTestView {
        let downloadViewButton = button(OmniBoxLocators.Buttons.downloadsButton.accessibilityIdentifier)
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
