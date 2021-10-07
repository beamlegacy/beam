//
//  SearchTestView.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation
import XCTest

class SearchTestView: BaseView {
    
    func getWebSearchField() -> XCUIElement {
        _ = self.textField(SearchViewLocators.TextFields.searchFieldWeb.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return self.textField(SearchViewLocators.TextFields.searchFieldWeb.accessibilityIdentifier)
    }
    
    func getCardSearchField() -> XCUIElement {
        _ = self.textField(SearchViewLocators.TextFields.searchFieldCard.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return self.textField(SearchViewLocators.TextFields.searchFieldCard.accessibilityIdentifier)
    }
    
    @discardableResult
    func typeInSearchField(_ searchText: String, isWebSearch: Bool , _ pressEnter: Bool = false) -> SearchTestView {
        let searchField = isWebSearch ? getWebSearchField() : getCardSearchField()
        searchField.click()
        searchField.typeText(searchText)
        if pressEnter {
            typeKeyboardKey(.enter)
        }
        return self
    }
    
    func closeSearchField() {
        self.image(SearchViewLocators.Buttons.closeButton.accessibilityIdentifier).click()
    }
    
    @discardableResult
    func navigateForward(numberOfTimes: Int = 1) -> SearchTestView {
        for _ in 1...numberOfTimes {
            self.image(SearchViewLocators.Buttons.forwardButton.accessibilityIdentifier).click()
        }
        return self
    }
    
    @discardableResult
    func navigateBackward(numberOfTimes: Int = 1) -> SearchTestView {
        for _ in 1...numberOfTimes {
            self.image(SearchViewLocators.Buttons.backwardButton.accessibilityIdentifier).click()
        }
        return self
    }
    
    @discardableResult
    func activateSearchField(isWebSearch: Bool) -> SearchTestView {
        triggerSearchField()
        let searchField = isWebSearch ? getWebSearchField() : getCardSearchField()
        searchField.tapInTheMiddle()
        return self
    }
    
    func getSearchFieldValue(isWebSearch: Bool) -> String {
        let searchField = isWebSearch ? getWebSearchField() : getCardSearchField()
        return searchField.value as? String ?? "\(String(describing: searchField.value)) unwrap issue"
    }
    
    func assertResultsCounterNumber(_ expectedValue: String) -> Bool {
        return self.staticText(expectedValue).waitForExistence(timeout: implicitWaitTimeout)
    }
}
