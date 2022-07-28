//
//  AdvancedSignInPasswordAutofillTests.swift
//  BeamUITests
//
//  Created by Frank Lefebvre on 11/04/2022.
//

import Foundation
import XCTest

class AdvancedSignInPasswordAutofillTests: BaseTest {

    let passwordUsername = "somePass@0"
    let passwordEmail = "somePass@1"
    let passwordEscape = "s.o'm\"e!P\\a&s?s@2/"
    let loginUsername = "signin.form"
    let loginEmail = "signin.form@email.beam"
    let loginEscape = "signin.form@escape.co"
    let securedAutoCompletedPassword = "••••••••••"

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .clearPasswordsDB()
            .populatePasswordsDB()
    }

    func testHiddenFieldsAreIgnored() {

        step("Given I navigate to visibility test page") {
            mockPage.openMockPage(.visibilityForm)
        }

        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Current Password: ").clickOnExistence()
        }
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: loginUsername)
        }
        step("Then the credentials are successfully populated") {
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "Current Username: ").getStringValue(), loginUsername)
            XCTAssertEqual(mockPage.getPasswordFieldElement(title: "Current Password: ").getStringValue(), securedAutoCompletedPassword)
        }

        step("When I click on sign up link") {
            mockPage.getLinkElement("Sign Up").clickOnExistence()
        }
        step("Then the credentials are empty") {
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "New Username: ").getStringValue(), "")
            XCTAssertEqual(mockPage.getPasswordFieldElement(title: "New Password: ").getStringValue(), "")
        }

        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username1"), loginUsername)
            XCTAssertEqual(mockPage.getResultValue(label: "password1"), passwordUsername)
            XCTAssertNil(mockPage.getResultValue(label: "username2"))
            XCTAssertNil(mockPage.getResultValue(label: "password2"))
        }
    }
    
//    Sign in auth combination are here: https://www.notion.so/Password-manager-authentication-combinations-650079c604c2458da446be10fd428995
    
    private func validateClassicSignInPage(page: MockHTTPWebPages.MockPageLink, login: String, password: String, autocomplete: Bool = true) {
        
        step("Given I navigate to \(mockPage.getMockPageUrl(page))") {
            mockPage.openMockPage(page)
        }
        
        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        if !autocomplete {
            step("Then create a new password is proposed") {
                XCTAssertTrue(passwordManagerHelper.doesSuggestNewPasswordExist())
            }
        } else {
            step("Then create a new password is not proposed") {
                XCTAssertFalse(passwordManagerHelper.doesSuggestNewPasswordExist())
            }
        }
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.getOtherPasswordsOptionElementFor(hostName: host).clickOnExistence()
            passwordManagerHelper.clickPopupLoginText(login: login)
        }
        
        step("Then the credentials are successfully populated") {
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "Email: ").getStringValue(), login)
            XCTAssertEqual(mockPage.getPasswordFieldElement(title: "Password: ").getStringValue(), securedAutoCompletedPassword)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), login)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), password)
        }
    }
    
    private func validateTwoStepsSignInPage(usernamePage: MockHTTPWebPages.MockPageLink, passwordPage: String, login: String, password: String) {
        
        step("Given I navigate to \(mockPage.getMockPageUrl(usernamePage))") {
            mockPage.openMockPage(usernamePage)
        }
        
        step("When I click on username field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
            passwordManagerHelper.getOtherPasswordsOptionElementFor(hostName: host).clickOnExistence()
        }
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: login)
        }
        
        step("Then the login is successfully populated") {
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "Email: ").getStringValue(), login)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then Sign in Step 2 is displayed") {
            shortcutHelper.shortcutActionInvoke(action: .openLocation)
            let url = OmniBoxTestView().getSearchFieldValue()
            XCTAssertTrue(url.contains(mockPage.getMockPageUrl(.mockBaseUrl) + passwordPage))
        }
        
        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password suggestion is proposed with correct login") {
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: login))
        }
        
        step("When I click on pop-up suggestion") {
            passwordManagerHelper.clickPopupLoginText(login: login)
        }
        
        step("Then the password is successfully populated") {
            XCTAssertEqual(mockPage.getPasswordFieldElement(title: "Password: ").getStringValue(), securedAutoCompletedPassword)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), login)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), password)
        }
    }
    
    func testSignInPageAuthCombination1() {
        validateClassicSignInPage(page: .signin1Form, login: loginUsername, password:passwordUsername, autocomplete: false)
    }
    
    func testSignInPageAuthCombination2() {
        validateClassicSignInPage(page: .signin2Form, login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination3() {
        validateClassicSignInPage(page: .signin3Form, login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination4() {
        validateClassicSignInPage(page: .signin4Form, login: loginEmail, password:passwordEmail)
    }
    
    func testSignInPageAuthCombination5() {
        
        step("Given I navigate to \(mockPage.getMockPageUrl(.signin5Form))") {
            mockPage.openMockPage(.signin5Form)
        }
        
        step("When I click on username field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginEmail))
            XCTAssertFalse(passwordManagerHelper.doesOtherPasswordsPopupExist())
        }
        
        step("When I fill username and I continue to display password") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickClearAndType(loginEmail)
            mockPage.getNextButtonElement().clickOnExistence()
        }
        
        step("And I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginEmail))
            XCTAssertFalse(passwordManagerHelper.doesOtherPasswordsPopupExist())
        }
    }
    
    func testSignInPageAuthCombination6() {
        validateTwoStepsSignInPage(usernamePage: .signin61Form, passwordPage: "signinstep2", login: loginEmail, password:passwordEmail)
    }

    func testSignInPageAuthCombination7() {
        validateTwoStepsSignInPage(usernamePage: .signin71Form, passwordPage: "signinstep2", login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination8() {
        validateClassicSignInPage(page: .signin8Form, login: loginEmail, password:passwordEmail, autocomplete: false)
    }
    
    func testSignInPageAuthCombination9() {
        validateTwoStepsSignInPage(usernamePage: .signin91Form, passwordPage: "signinpage9-2", login: loginEmail, password:passwordEmail)
    }
    
    func testSignInPageWithTextfieldAutocompleted() {
        let testData = "test"
        
        step("Given I navigate to \(mockPage.getMockPageUrl(.signinebayForm))") {
            mockPage.openMockPage(.signinebayForm)
        }
        
        step("When I click on Name field") {
            mockPage.getUsernameFieldElement(title: "Name: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginEmail))
            XCTAssertFalse(passwordManagerHelper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Name: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Lastname field") {
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginUsername))
            XCTAssertFalse(passwordManagerHelper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginUsername))
            XCTAssertTrue(passwordManagerHelper.doesSuggestNewPasswordExist())
        }
        
        step("When I click on Email field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginUsername))
        }
        
        step("When I fill information") {
            passwordManagerHelper.clickPopupLoginText(login: loginUsername)
        }
        
        step("And I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "firstname"), testData)
            XCTAssertEqual(mockPage.getResultValue(label: "lastname"), testData)
            XCTAssertEqual(mockPage.getResultValue(label: "username"), loginUsername)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), passwordUsername)
        }
    }

    func testSignInPageWithPasswordContainingSpecialCharacters() {

        step("Given I navigate to \(mockPage.getMockPageUrl(.signinForm))") {
            mockPage.openMockPage(.signinForm)
        }

        step("When I click on Username field") {
            mockPage.getUsernameFieldElement(title: "Username: ").clickOnExistence()
        }

        step("And I click on Other Passwords option") {
            passwordManagerHelper.getOtherPasswordsOptionElementFor(hostName: "form.lvh.me").clickOnExistence()
        }

        step("When I fill information") {
            passwordManagerHelper.clickPopupLoginText(login: loginEscape)
        }

        step("And I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }

        step("Then the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), loginEscape)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), passwordEscape)
        }
    }

    func testPasswordMenuIsDismissedWhenNavigatingBack() {
        step("Given I navigate to \(mockPage.getMockPageUrl(.shortcutsUrl))") {
            mockPage.openMockPage(.shortcutsUrl)
        }
        step("And I navigate to Sign In page") {
            mockPage.getLinkElement("Sign In", inView: "Shortcuts").clickOnExistence()
        }
        step("When I click on Username field") {
            mockPage.getUsernameFieldElement(title: "Username: ").clickOnExistence()
        }
        step("Then password manager is displayed") {
            XCTAssertTrue(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginUsername))
        }
        step("When I navigate back") {
            _ = webView.browseHistoryBackButtonClick()
        }
        step("Then password manager is not displayed") {
            XCTAssertFalse(passwordManagerHelper.doesAutofillPopupExist(autofillText: loginUsername))
        }
    }
}
