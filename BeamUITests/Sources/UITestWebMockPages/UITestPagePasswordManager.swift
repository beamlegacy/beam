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
        clickInputField(formLabel).typeText(value)
    }
    
    @discardableResult
    func clickInputField(_ formLabel: FormInputs) -> XCUIElement {
        let parent = app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let input = parent.staticTexts[formLabel.rawValue].firstMatch
        XCTAssert(input.waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        input.tapInTheMiddle()
        return input
    }

    func tapSubmit() {
        let target = "Submit"
        let parent = app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        button.tapInTheMiddle()
    }
    
    func getInputValue(_ formLabel: FormInputs) -> String {
        let parent = app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let value = formLabel == FormInputs.username ? getElementStringValue(element: parent.textFields.firstMatch) : getElementStringValue(element: parent.secureTextFields.firstMatch)
        return value
    }
    
    func isPasswordPageOpened() -> Bool {
        return self.button("Submit").waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
}
