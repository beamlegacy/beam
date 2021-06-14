//
//  PasswordManagerUITests.swift
//  BeamUITests
//
//  Created by Stef Kors on 14/06/2021.
//

import XCTest
import XCTest
#if canImport(Quick)
import Quick
#endif
#if canImport(Nimble)
import Nimble
#endif
import BeamCore

class PasswordManagerUITests: XCTestCase {
    let app = XCUIApplication()
    var helper: BeamUITestsHelper!

    enum FormInputs: String {
        case username = "Username"
        case password = "Password"
    }

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        self.app.launch()
        self.helper = BeamUITestsHelper(self.app)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func enterInput(_ value: String, _ formLabel: FormInputs) {
        let parent = self.app.webViews.containing(.staticText, identifier: formLabel.rawValue).element
        let input = parent.staticTexts[formLabel.rawValue].firstMatch
        XCTAssert(input.waitForExistence(timeout: 4))
        let inputMiddle = input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        inputMiddle.tap()
        inputMiddle.click()
        input.typeText(value)
    }

    func tapSubmit() {
        let target = "Submit"
        let parent = self.app.webViews.containing(.button, identifier: target).element
        let button = parent.buttons[target].firstMatch
        XCTAssert(button.waitForExistence(timeout: 4))
        let buttonMiddle = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        buttonMiddle.tap()
    }

    func testLogin() throws {
        self.helper.openTestPage(number: 4)
        enterInput(self.helper.randomEmail(), .username)
        enterInput(self.helper.randomPassword(), .password)
        tapSubmit()
        let confirmationToast = self.app.staticTexts["CredentialsConfirmationToast"]
        XCTAssertTrue(confirmationToast.waitForExistence(timeout: 4))
    }

}
