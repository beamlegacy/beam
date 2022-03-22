//
//  OmniBoxUITestsHelper.swift
//  BeamUITests
//
//  Created by Remi Santos on 07/05/2021.
//

import Foundation
import XCTest

class OmniBoxUITestsHelper : BeamUITestsHelper {
    let searchField: XCUIElement
    let autocompleteResultPredicate = NSPredicate(format: "identifier CONTAINS 'autocompleteResult'")
    let autocompleteSelectedPredicate = NSPredicate(format: "identifier CONTAINS '-selected'")
    let autocompleteCreateCardPredicate = NSPredicate(format: "identifier CONTAINS '-createNote'")
    let autocompleteNotePredicate = NSPredicate(format: "identifier CONTAINS '-note'")

    let allAutocompleteResults: XCUIElementQuery

    override init(_ app: XCUIApplication) {
        searchField = app.searchFields["OmniboxSearchField"]
        allAutocompleteResults = app.otherElements.matching(self.autocompleteResultPredicate)
        super.init(app)
    }

    func cleanupDB(logout: Bool) {
        if logout {
            self.tapCommand(.logout)
        }
        self.tapCommand(.destroyDB)
    }

    func focusSearchField() {
        self.searchField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func inputHasFocus(_ input: XCUIElement) -> Bool {
        return input.value(forKey: "hasKeyboardFocus") as? Bool ?? false
    }

    func navigateTo(text: String) {
        self.focusSearchField()
        self.searchField.typeText(text)
        self.searchField.typeText("\r")
    }
}
