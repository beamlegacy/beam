//
//  NotesPreferencesTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 20.07.2022.
//

import Foundation
import XCTest

class NotesPreferencesTestView: PreferencesBaseView {
    
    func getAlwaysShowBulletsCheckbox() -> XCUIElement {
        return checkBox(NotesPreferencesViewLocators.Checkboxes.alwaysShowBullets.accessibilityIdentifier)
    }
    
    func getCursorColorDropDownElement() -> XCUIElement {
        return popUpButton(NotesPreferencesViewLocators.PopUpButtons.cursorColor.accessibilityIdentifier)
    }
    
    func getCursorColorValues() -> [String] {
        _ = getCursorColorDropDownElement().menus.menuItems.firstMatch.waitForExistence(timeout: minimumWaitTimeout)
        let cursorValuesElements = getCursorColorDropDownElement().menus.menuItems.allElementsBoundByIndex
        var cursorValues = [String]()
        cursorValuesElements.forEach {
            cursorValues.append($0.title)
        }
        return cursorValues
    }
    
    func selectCursorColorBy(colorName: String) -> NotesPreferencesTestView {
        getCursorColorDropDownElement().menus.menuItems[colorName].firstMatch.hoverAndTapInTheMiddle()
        return self
    }
    
    func isColorSelectedAs(expectedColorName: String) -> Bool {
        return waitForStringValueEqual(expectedColorName, getCursorColorDropDownElement())
    }
    
}
