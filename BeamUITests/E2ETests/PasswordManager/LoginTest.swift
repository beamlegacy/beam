//
//  LoginTest.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class LoginTest: BaseTest {
    
    enum FormInputs: String {
        case username = "Username"
        case password = "Password"
    }
    
    func enterInput(_ value: String, _ formLabel: FormInputs, _ app: XCUIApplication) {
        let parent = app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let input = parent.staticTexts[formLabel.rawValue].firstMatch
        XCTAssert(input.waitForExistence(timeout: implicitWaitTimeout))
        let inputMiddle = input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        inputMiddle.tap()
        inputMiddle.click()
        input.typeText(value)
    }

    func tapSubmit(_ app: XCUIApplication) {
        let target = "Submit"
        let parent = app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: 4))
        let buttonMiddle = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        buttonMiddle.tap()
    }
    
    func testloginFormAuthentication() {
        let journalView = launchApp()
        let helper = BeamUITestsHelper(journalView.app)

        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        
        enterInput(helper.randomEmail(), .username, journalView.app)
        enterInput(helper.randomPassword(), .password, journalView.app)
        tapSubmit(journalView.app)

        let button = journalView.app.buttons["Save Password"].firstMatch
        XCTAssert(button.waitForExistence(timeout: 4))
        button.tapInTheMiddle()

        let confirmationToast = journalView.app.staticTexts["CredentialsConfirmationToast"]
        XCTAssertTrue(confirmationToast.waitForExistence(timeout: implicitWaitTimeout))
    }
    
}
