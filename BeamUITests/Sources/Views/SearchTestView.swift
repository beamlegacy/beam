//
//  SearchTestView.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation
import XCTest

class SearchTestView: BaseView {
    
    func getSearchFieldElement() -> XCUIElement {
        return textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier)
    }
    
    @discardableResult
    func typeInSearchField(_ searchText: String, _ pressEnter: Bool = false) -> SearchTestView {
        let searchField = self.getSearchFieldElement()
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
        self.getSearchFieldElement().tapInTheMiddle()
        return self
    }
    
    func getSearchFieldValue(isWebSearch: Bool) -> String {
        return getElementStringValue(element: self.getSearchFieldElement())
    }
    
    func assertResultsCounterNumber(_ expectedValue: String) -> Bool {
        return self.staticText(expectedValue).waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
}
