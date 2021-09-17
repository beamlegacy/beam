//
//  SearchTestView.swift
//  BeamUITests
//
//  Created by Andrii on 09.09.2021.
//

import Foundation
import XCTest

class SearchTestView: BaseView {
    
    func getSearchField() -> XCUIElement {
        _ = self.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier).waitForExistence(timeout: implicitWaitTimeout)
        return self.textField(SearchViewLocators.TextFields.searchField.accessibilityIdentifier)
    }
    
    @discardableResult
    func typeInSearchField(_ searchText: String, _ pressEnter: Bool = false) -> SearchTestView {
        getSearchField().click()
        getSearchField().typeText(searchText)
        if pressEnter {
            typeKeyboardKey(.enter)
        }
        return self
    }
    
    @discardableResult
    func triggerSearchField() -> SearchTestView {
        app.typeKey("f", modifierFlags:.command)
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
    
    func assertResultsCounterNumber(_ expectedValue: String) -> Bool {
        return self.staticText(expectedValue).waitForExistence(timeout: implicitWaitTimeout)
    }
}
