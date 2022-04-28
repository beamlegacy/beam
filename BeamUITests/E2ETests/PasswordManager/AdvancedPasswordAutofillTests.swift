//
//  AdvancedPasswordAutofillTests.swift
//  BeamUITests
//
//  Created by Frank Lefebvre on 11/04/2022.
//

import Foundation
import XCTest

class AdvancedPasswordAutofillTests: BaseTest {

    let uiMenu = UITestsMenuBar()
    let mockPage = MockHTTPWebPages()
    let helper = PasswordManagerHelper()
    let passwordUsername = "somePass@0"
    let passwordEmail = "somePass@1"
    let baseUrl = "http://form.lvh.me:8080/"
    let loginUsername = "signin.form"
    let loginEmail = "signin.form@email.beam"
    let securedAutoCompletedPassword = "••••••••••"

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
    }

    func testHiddenFieldsAreIgnored() {
        let url = baseUrl + "visibility"

        step("Given I navigate to visibility test page") {
            OmniBoxTestView().searchInOmniBox(url, true)
        }

        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Current Password: ").clickOnExistence()
        }
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: loginUsername)
        }
        step("Then the credentials are successfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "Current Username: ")), loginUsername)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "Current Password: ")), securedAutoCompletedPassword)
        }

        step("When I click on sign up link") {
            mockPage.getLinkElement("Sign Up").clickOnExistence()
        }
        step("Then the credentials are empty") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "New Username: ")), "")
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "New Password: ")), "")
        }

        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "username1"), loginUsername)
            XCTAssertEqual(mockPage.getResultValue(label: "password1"), passwordUsername)
            XCTAssertNil(mockPage.getResultValue(label: "username2"))
            XCTAssertNil(mockPage.getResultValue(label: "password2"))
        }
    }
    
//    Sign in auth combination are here: https://www.notion.so/Password-manager-authentication-combinations-650079c604c2458da446be10fd428995
    
    private func validateClassicSignInPage(page: String, login: String, password: String, autocomplete: Bool = true) {
        
        step("Given I navigate to \(page)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + page, true)
        }
        
        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        if !autocomplete {
            step("Then create a new password is proposed") {
                XCTAssertTrue(helper.doesSuggestNewPasswordExist())
            }
        } else {
            step("Then create a new password is not proposed") {
                XCTAssertFalse(helper.doesSuggestNewPasswordExist())
            }
        }
        
        step("When I click on pop-up suggestion") {
            helper.getOtherPasswordsOptionElementFor(hostName: host).clickOnExistence()
            helper.clickPopupLoginText(login: login)
        }
        
        step("Then the credentials are successfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "Email: ")), login)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "Password: ")), securedAutoCompletedPassword)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "username"), login)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), password)
        }
    }
    
    private func validateTwoStepsSignInPage(usernamePage: String, passwordPage: String, login: String, password: String) {
        
        step("Given I navigate to \(usernamePage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + usernamePage, true)
        }
        
        step("When I click on username field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
            helper.getOtherPasswordsOptionElementFor(hostName: host).clickOnExistence()
        }
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: login)
        }
        
        step("Then the login is successfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "Email: ")), login)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then Sign in Step 2 is displayed") {
            ShortcutsHelper().shortcutActionInvoke(action: .openLocation)
            let url = OmniBoxTestView().getSearchFieldValue()
            XCTAssertTrue(url.contains(baseUrl + passwordPage))
        }
        
        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password suggestion is proposed with correct login") {
            XCTAssertTrue(helper.doesAutofillPopupExist(login: login))
        }
        
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: login)
        }
        
        step("Then the password is successfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "Password: ")), securedAutoCompletedPassword)
        }
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "username"), login)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), password)
        }
    }
    
    func testSignInPageAuthCombination1() {
        validateClassicSignInPage(page: "signinpage1", login: loginUsername, password:passwordUsername, autocomplete: false)
    }
    
    func testSignInPageAuthCombination2() {
        validateClassicSignInPage(page: "signinpage2", login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination3() {
        validateClassicSignInPage(page: "signinpage3", login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination4() {
        validateClassicSignInPage(page: "signinpage4", login: loginEmail, password:passwordEmail)
    }
    
    func testSignInPageAuthCombination5() {
        let usernamePage = "signinpage5"
        
        step("Given I navigate to \(usernamePage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + usernamePage, true)
        }
        
        step("When I click on username field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginEmail))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
        }
        
        step("When I fill username and I continue to display password") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickClearAndType(loginEmail)
            mockPage.getNextButtonElement().clickOnExistence()
        }
        
        step("And I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginEmail))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
        }
    }
    
    func testSignInPageAuthCombination6() {
        validateTwoStepsSignInPage(usernamePage: "signinpage6-1", passwordPage: "signinstep2", login: loginEmail, password:passwordEmail)
    }

    func testSignInPageAuthCombination7() {
        validateTwoStepsSignInPage(usernamePage: "signinpage7-1", passwordPage: "signinstep2", login: loginUsername, password:passwordUsername)
    }
    
    func testSignInPageAuthCombination8() {
        validateClassicSignInPage(page: "signinpage8", login: loginEmail, password:passwordEmail, autocomplete: false)
    }
    
    func testSignInPageAuthCombination9() {
        validateTwoStepsSignInPage(usernamePage: "signinpage9-1", passwordPage: "signinpage9-2", login: loginEmail, password:passwordEmail)
    }
    
    func testSignInPageWithTextfieldAutocompleted() {
        let usernamePage = "signinebay"
        let testData = "test"
        
        step("Given I navigate to \(usernamePage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + usernamePage, true)
        }
        
        step("When I click on Name field") {
            mockPage.getUsernameFieldElement(title: "Name: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginEmail))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Name: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Lastname field") {
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginUsername))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(helper.doesAutofillPopupExist(login: loginUsername))
            XCTAssertTrue(helper.doesSuggestNewPasswordExist())
        }
        
        step("When I click on Email field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(helper.doesAutofillPopupExist(login: loginUsername))
        }
        
        step("When I fill information") {
            helper.clickPopupLoginText(login: loginUsername)
        }
        
        step("And I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        
        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "firstname"), testData)
            XCTAssertEqual(mockPage.getResultValue(label: "lastname"), testData)
            XCTAssertEqual(mockPage.getResultValue(label: "username"), loginUsername)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), passwordUsername)
        }
    }
}
