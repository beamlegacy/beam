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
    let passwordsWindow = PasswordPreferencesTestView()

    var email: String = ""
    var password: String = ""
    let testUrl = "UITests-Password.html"
        
    func preparation() -> AlertTestView {
        launchApp()
        email = self.getRandomEmail()
        password = self.getRandomPassword()
        uiMenu.loadUITestPagePassword()
        testPage.enterInput(password, .password) //password first to avoid Other Passwords cover over the Submit button
        testPage.enterInput(email, .username)
        // close Other Passwords if it still covers Submit button
        if passwordManagerHelper.getOtherPasswordsOptionElement().exists {
            testPage.typeKeyboardKey(.escape)
        }
        testPage.tapSubmit()
        return AlertTestView()
    }
    
    func testloginFormPasswordSave() {
        testrailId("C857")
        step ("WHEN I save password during my navigation"){
            preparation().savePassword(waitForAlertToDisappear: false)
        }
        
        step ("THEN toast is displayed to confirm"){
            XCTAssertTrue(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: BaseTest.implicitWaitTimeout))
        }

        step ("AND it is saved in password preferences"){
            uiMenu.disablePasswordAndCardsProtection()
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(testUrl))
            XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(email))
            XCTAssertEqual(passwordsWindow.getNumberOfEntries(),1)
            passwordsWindow.selectFirstPasswordItem(testUrl)
            passwordsWindow.clickDetails()
            XCTAssertEqual(passwordsWindow.getPasswordFieldToFill(.site).getStringValue(), testUrl)
            XCTAssertEqual(passwordsWindow.getPasswordFieldToFill(.username).getStringValue(), email)
            XCTAssertEqual(passwordsWindow.getPasswordFieldToFill(.password).getStringValue(), password)
        }
    }
    
    func testloginFormPasswordSaveCancellation() {
        testrailId("C902")
        preparation().notNowClick()

        step ("THEN no toast is displayed"){
            XCTAssertFalse(testPage.staticText("CredentialsConfirmationToast").waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step ("AND it is not saved in password preferences"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            XCTAssertFalse(passwordsWindow.isPasswordDisplayed())
        }
    }
}
