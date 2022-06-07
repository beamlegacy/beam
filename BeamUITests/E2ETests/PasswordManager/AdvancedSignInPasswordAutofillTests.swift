//
//  AdvancedSignInPasswordAutofillTests.swift
//  BeamUITests
//
//  Created by Frank Lefebvre on 11/04/2022.
//

import Foundation
import XCTest

class AdvancedSignInPasswordAutofillTests: BaseTest {

    let uiMenu = UITestsMenuBar()
    let mockPage = MockHTTPWebPages()
    let helper = PasswordManagerHelper()
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
    
    private func validateClassicSignInPage(page: MockHTTPWebPages.MockPageLink, login: String, password: String, autocomplete: Bool = true) {
        
        step("Given I navigate to \(mockPage.getMockPageUrl(page))") {
            mockPage.openMockPage(page)
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
    
    private func validateTwoStepsSignInPage(usernamePage: MockHTTPWebPages.MockPageLink, passwordPage: String, login: String, password: String) {
        
        step("Given I navigate to \(mockPage.getMockPageUrl(usernamePage))") {
            mockPage.openMockPage(usernamePage)
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
            XCTAssertTrue(url.contains(mockPage.getMockPageUrl(.mockBaseUrl) + passwordPage))
        }
        
        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password suggestion is proposed with correct login") {
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: login))
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
            XCTAssertFalse(helper.doesAutofillPopupExist(autofillText: loginEmail))
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
            XCTAssertFalse(helper.doesAutofillPopupExist(autofillText: loginEmail))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
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
            XCTAssertFalse(helper.doesAutofillPopupExist(autofillText: loginEmail))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Name: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Lastname field") {
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(autofillText: loginUsername))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist())
            mockPage.getUsernameFieldElement(title: "Lastname: ").clickClearAndType(testData)
            mockPage.typeKeyboardKey(.escape) // Do not choose autocomplete
        }
        
        step("When I click on Password field") {
            mockPage.getPasswordFieldElement(title: "Password: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: loginUsername))
            XCTAssertTrue(helper.doesSuggestNewPasswordExist())
        }
        
        step("When I click on Email field") {
            mockPage.getUsernameFieldElement(title: "Email: ").clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertTrue(helper.doesAutofillPopupExist(autofillText: loginUsername))
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

    func testSignInPageWithPasswordContainingSpecialCharacters() {

        step("Given I navigate to \(mockPage.getMockPageUrl(.signinForm))") {
            mockPage.openMockPage(.signinForm)
        }

        step("When I click on Username field") {
            mockPage.getUsernameFieldElement(title: "Username: ").clickOnExistence()
        }

        step("And I click on Other Passwords option") {
            helper.getOtherPasswordsOptionElementFor(hostName: "form.lvh.me").clickOnExistence()
        }

        step("When I fill information") {
            helper.clickPopupLoginText(login: loginEscape)
        }

        step("And I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }

        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "username"), loginEscape)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), passwordEscape)
        }
    }
}
