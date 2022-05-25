//
//  PasswordManagerHelper.swift
//  BeamUITests
//
//  Created by Andrii on 23.09.2021.
//

import Foundation
import XCTest

class PasswordManagerHelper: BaseView {
    
    let login = "qa@beamapp.co"
    let password = "somePassword"
    
    func doesAutofillPopupExist(autofillText: String, timeout: Double = BaseTest.minimumWaitTimeout) -> Bool {
        return getAutofillPopupElement(autofillText: autofillText).waitForExistence(timeout: timeout)
    }
    
    func doesOtherPasswordsPopupExist(timeout: Double = BaseTest.minimumWaitTimeout ) -> Bool {
        return getOtherPasswordsOptionElement().waitForExistence(timeout: timeout)
    }
    
    func doesOtherCCPopupExist(timeout: Double = BaseTest.minimumWaitTimeout ) -> Bool {
        return getOtherCCOptionElement().waitForExistence(timeout: timeout)
    }
    
    func doesSuggestNewPasswordExist() -> Bool {
        return getSuggestNewPassword().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }

    func clickKeyIcon() {
        getKeyIconElement().clickOnExistence()
    }
    
    func clickPopupLoginText(login: String) {
        app.dialogs.staticTexts[login].clickOnExistence()
    }

    func getKeyIconElement() -> XCUIElement {
        app.dialogs.buttons["autofill-password"]
    }

    func getAutofillPopupElement(autofillText: String) -> XCUIElement {
        return app.dialogs.containing(.staticText, identifier: autofillText).element
    }
    
    func getOtherPasswordsOptionElement() -> XCUIElement {
        return app.staticTexts["Other Passwords..."]
    }
    
    func getOtherCCOptionElement() -> XCUIElement {
        return app.staticTexts["Other Credit Cards..."]
    }
    
    func getOtherPasswordsOptionElementFor(hostName: String) -> XCUIElement {
        return app.staticTexts["Other Passwords for " + hostName]
    }
    
    func getSuggestNewPassword() -> XCUIElement {
        return app.staticTexts["Suggest new password"]
    }
    
    @discardableResult
    func openPasswordPreferences() -> AutoFillPasswordsTestView {
        getOtherPasswordsOptionElement().clickOnExistence()
        return AutoFillPasswordsTestView()
    }
    
    @discardableResult
    func openCCPreferences() -> AutoFillCCTestView {
        getOtherCCOptionElement().clickOnExistence()
        return AutoFillCCTestView()
    }
    
    func doesAutogeneratedPasswordPopupExist(timeout: Double = BaseTest.minimumWaitTimeout) -> Bool {
        return app.staticTexts["Suggested Password"].waitForExistence(timeout: timeout)
    }
    
    func getAutogeneratedPasswordPopupIcon() -> XCUIElement {
        return app.images["autofill-password_xs"]
    }
    
    @discardableResult
    func useAutogeneratedPassword() -> WebTestView {
        app.buttons["Use Password"].clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func dontUseAutogeneratedPassword() -> WebTestView {
        app.buttons["Don't Use"].clickOnExistence()
        return WebTestView()
    }
    
    func signInGoogle() -> Bool {
        staticText("Sign in").clickOnExistence()
        searchField("Email or phone").typeText(login)
        let nextButton = button("Next")
        nextButton.clickOnHittable()
        secureTextField("Enter your password").click()
        secureTextField("Enter your password").typeText(password)
        nextButton.click()
        return button("Google Account: qa none  \n(qa@beamapp.co)").waitForExistence(timeout: BaseTest.implicitWaitTimeout)
    }
    
}
