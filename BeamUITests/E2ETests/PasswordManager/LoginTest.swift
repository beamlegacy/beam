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
    let shortcutsHelper = ShortcutsHelper()
    let passwordsWindow = PasswordPreferencesTestView()

    var email: String = ""
    var password: String = ""
    let testUrl = "UITests-Password.html"
        
    func preparation() -> AlertTestView {
        let helper = BeamUITestsHelper(launchApp().app)
        email = helper.randomEmail()
        password = helper.randomPassword()
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        testPage.enterInput(password, .password) //password first to avoid Other Passwords cover over the Submit button
        testPage.enterInput(email, .username)
        // close Other Passwords if it still covers Submit button
        if PasswordManagerHelper().getOtherPasswordsOptionElement().exists {
            testPage.typeKeyboardKey(.escape)
        }
        testPage.tapSubmit()
        return AlertTestView()
    }
    
    func testloginFormPasswordSave() {
        step ("WHEN I save password during my navigation"){
            preparation().savePassword(waitForAlertToDisappear: false)
        }
        
        step ("THEN toast is displayed to confirm"){
            XCTAssertTrue(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step ("AND it is saved in password preferences"){
            shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(menu: .passwords)
            XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(testUrl))
            XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(email))
            XCTAssertEqual(passwordsWindow.getNumberOfEntries(),1)
            passwordsWindow.selectPassword(testUrl)
            passwordsWindow.clickDetails()
            XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.site)), testUrl)
            XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.username)), email)
            XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.password)), password)
        }
    }
    
    func testloginFormPasswordSaveCancellation() {
        preparation().notNowClick()

        step ("THEN no toast is displayed"){
            XCTAssertFalse(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step ("AND it is not saved in password preferences"){
            shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(menu: .passwords)
            XCTAssertFalse(passwordsWindow.isPasswordDisplayed())
        }
    }
}
