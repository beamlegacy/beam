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
        XCTAssert(button.waitForExistence(timeout: minimumWaitTimeout))
        let buttonMiddle = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        buttonMiddle.tap()
    }
    
    func testloginFormPasswordSave() {
        let journalView = preparartion()
        //to be moved in a test view once https://gitlab.com/beamgroup/beam/-/merge_requests/1410 is merged
        handleCredentialsPopUp("Save Password", journalView)

        XCTAssertTrue(journalView.staticText("CredentialsConfirmationToast").waitForExistence(timeout: implicitWaitTimeout))
        //to be added - assertion in password preferences - it exists there. Password cleaning required
    }
    
    func testloginFormPasswordSaveCancellation() {
        let journalView = preparartion()
        //to be moved in a test view once https://gitlab.com/beamgroup/beam/-/merge_requests/1410 is merged
        handleCredentialsPopUp("Not Now", journalView)

        XCTAssertFalse(journalView.staticText("CredentialsConfirmationToast").waitForExistence(timeout: minimumWaitTimeout))
        //to be added - assertion in password preferences - it exists there. Password cleaning required
    }
    
    func preparartion() -> JournalTestView {
        let journalView = launchApp()
        
        let helper = BeamUITestsHelper(journalView.app)

        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        enterInput(helper.randomPassword(), .password, journalView.app) //password first to avoid Other Passwords cover over the Submit button
        enterInput(helper.randomEmail(), .username, journalView.app)
        // close Other Passwords if it still covers Submit button
        if PasswordManagerHelper().getOtherPasswordsOptionElement().exists {
            journalView.typeKeyboardKey(.escape)
        }
        tapSubmit(journalView.app)
        return journalView
    }
    
    func handleCredentialsPopUp(_ buttonOption: String, _ view: JournalTestView) {
        let button = view.button(buttonOption)
        XCTAssertTrue(button.waitForExistence(timeout: implicitWaitTimeout))
        WaitHelper().waitForIsEnabled(button)
        button.tapInTheMiddle()
    }
    
}
