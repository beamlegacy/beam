//
//  LoginTest.swift
//  BeamUITests
//
//  Created by Andrii on 06.08.2021.
//

import Foundation
import XCTest

class LoginTest: BaseTest {
    
    let testPage = UITestPagePasswordManager()
    let alert = AlertTestView()
    
    func testloginFormPasswordSave() {
        preparartion().savePassword(waitForAlertToDisappear: false)

        XCTAssertTrue(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: implicitWaitTimeout))
        //to be added - assertion in password preferences - it exists there. Password cleaning required
    }
    
    func testloginFormPasswordSaveCancellation() {
        preparartion().notNowClick()

        XCTAssertFalse(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: minimumWaitTimeout))
        //to be added - assertion in password preferences - it exists there. Password cleaning required
    }
    
    func preparartion() -> AlertTestView {
        let helper = BeamUITestsHelper(launchApp().app)

        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        testPage.enterInput(helper.randomPassword(), .password) //password first to avoid Other Passwords cover over the Submit button
        testPage.enterInput(helper.randomEmail(), .username)
        // close Other Passwords if it still covers Submit button
        if PasswordManagerHelper().getOtherPasswordsOptionElement().exists {
            testPage.typeKeyboardKey(.escape)
        }
        testPage.tapSubmit()
        return AlertTestView()
    }
    
    func handleCredentialsPopUp(_ buttonOption: String) {
        let button = testPage.button(buttonOption)
        XCTAssertTrue(button.waitForExistence(timeout: implicitWaitTimeout))
        WaitHelper().waitForIsEnabled(button)
        button.tapInTheMiddle()
    }
    
}
