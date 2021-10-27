//
//  UITestPagePasswordManager.swift
//  BeamUITests
//
//  Created by Andrii on 13/10/2021.
//

import Foundation
import XCTest

class UITestPagePasswordManager: BaseView {
    
    enum FormInputs: String {
        case username = "Username"
        case password = "Password"
    }
    
    func enterInput(_ value: String, _ formLabel: FormInputs) {
        let parent = app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let input = parent.staticTexts[formLabel.rawValue].firstMatch
        XCTAssert(input.waitForExistence(timeout: implicitWaitTimeout))
        input.doubleTapInTheMiddle()
        input.typeText(value)
    }

    func tapSubmit() {
        let target = "Submit"
        let parent = app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: minimumWaitTimeout))
        button.tapInTheMiddle()
    }
    
    func getInputValue(_ formLabel: FormInputs) -> String {
        let parent = app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let value = formLabel == FormInputs.username ? getElementStringValue(element: parent.textFields.firstMatch) : getElementStringValue(element: parent.secureTextFields.firstMatch)
        return value
    }
    
    func isPasswordPageOpened() -> Bool {
        return self.button("Submit").waitForExistence(timeout: minimumWaitTimeout)
    }
    
}
