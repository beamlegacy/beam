//
//  OmniBarUITestsHelper.swift
//  BeamUITests
//
//  Created by Remi Santos on 07/05/2021.
//

import Foundation
import XCTest

class OmniBarUITestsHelper : BeamUITestsHelper {
    let searchField: XCUIElement
    let autocompleteResultPredicate = NSPredicate(format: "identifier CONTAINS 'autocompleteResult'")
    let autocompleteSelectedPredicate = NSPredicate(format: "identifier CONTAINS '-selected'")
    let autocompleteCreateCardPredicate = NSPredicate(format: "identifier CONTAINS '-createCard'")

    let allAutocompleteResults: XCUIElementQuery

    override init(_ app: XCUIApplication) {
        searchField = app.searchFields["OmniBarSearchField"]
        allAutocompleteResults = app.otherElements.matching(self.autocompleteResultPredicate)
        super.init(app)
    }

    func cleanupDB() {
        self.tapCommand(.logout)
        self.tapCommand(.destroyDB)
    }

    func focusSearchField() {
        self.searchField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func typeInSearchAndWait(_ text: String) {
        self.searchField.typeText(text)
        waitForSearchResults()
    }

    func waitForSearchResults() {
        usleep(500000) // 0.5s
    }

    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }

    func navigateTo(text: String) {
        XCUIApplication().menuItems["Open Location"].tap()
        self.searchField.typeText(text)
        self.searchField.typeText("\r")
    }
}
