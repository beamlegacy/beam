//
//  AdvancedSignUpPasswordAutofillTests.swift
//  BeamUITests
//
//  Created by Quentin Valero on 11/05/2022.
//

import Foundation
import XCTest

class AdvancedSignUpPasswordAutofillTests: BaseTest {

    let alertView = AlertTestView()
    let uiMenu = UITestsMenuBar()
    let mockPage = MockHTTPWebPages()
    let helper = PasswordManagerHelper()
    let baseUrl = "http://form.lvh.me:8080/"
    let firstName = "Jean"
    let lastName = "Martin"
    let phone = "0123456789"
    let gender = "Gender"
    let day = "01"
    let month = "February"
    let year = "2000"
    let view = "Sign Up"
    let loginUsername = "signin.form"
    let loginEmail = "signin.form@email.beam"
    let securedAutoCompletedPassword = "••••••••••••••••••••"
    let timeout = 0.5
    var generatedPassword = "password"

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
    }

    private func verifyPwManagerNotDisplayedDropdown(field: String, data: String) {
        step("When I click on \(field) field") {
            mockPage.getDropdownFieldElement(title: field, inView: view).clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginUsername, timeout: timeout))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist(timeout: timeout))
        }
    }
    
    private func verifyPwManagerNotDisplayedTextField(field: String, data: String) {
        step("When I click on \(field) field") {
            mockPage.getUsernameFieldElement(title: field, inView: view).clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginUsername, timeout: timeout))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist(timeout: timeout))
        }
    }
    
    private func fillDataWithoutPwManager(field: String, data: String) {
        step("When I click on \(field) field") {
            mockPage.getUsernameFieldElement(title: field, inView: view).clickOnExistence()
        }
        
        step("Then password manager is not displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginUsername, timeout: timeout))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist(timeout: timeout))
            mockPage.getUsernameFieldElement(title: field, inView: view).clickClearAndType(data)
            mockPage.typeKeyboardKey(.escape) // In case of autocomplete
        }
    }
    
    private func fillPasswordFieldWithSuggestedPassword(field: String = "Password: ") {
        step("When I click on Password field") {
            mockPage.getPasswordFieldElement(title: field, inView: view).clickOnExistence()
        }
        
        step("Then password manager is displayed") {
            XCTAssertFalse(helper.doesAutofillPopupExist(login: loginEmail, timeout: timeout))
            XCTAssertFalse(helper.doesOtherPasswordsPopupExist(timeout: timeout))
            XCTAssertTrue(helper.doesAutogeneratedPasswordPopupExist(timeout: timeout))
            generatedPassword = mockPage.getElementStringValue(element: mockPage.getPasswordElementWithValue(title: field, inView: view))
            helper.useAutogeneratedPassword()
        }
    }
    
    func testSignUpPageCombination1() {
        let signUpPage = "signuppage1"
        
        step("Given I navigate to \(signUpPage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + signUpPage, true)
        }
        
        verifyPwManagerNotDisplayedTextField(field: "First Name: ", data: firstName)
        verifyPwManagerNotDisplayedTextField(field: "Last Name: ", data: lastName)
        fillDataWithoutPwManager(field: "Username: ", data: loginUsername)
        fillPasswordFieldWithSuggestedPassword()
        verifyPwManagerNotDisplayedTextField(field: "Phone: ", data: phone)
        verifyPwManagerNotDisplayedTextField(field: "Gender: ", data: gender)
        verifyPwManagerNotDisplayedDropdown(field: "Month: ", data: month)
        verifyPwManagerNotDisplayedTextField(field: "Day: ", data: day)
        verifyPwManagerNotDisplayedTextField(field: "Year: ", data: year)
        
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the result page is populated with sign up data") {
            alertView.notNowClick() // will fail if pop up is not displayed
            XCTAssertEqual(mockPage.getResultValue(label: "username"), loginUsername)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), generatedPassword)
        }
    }
    
    func testSignUpPageCombination2() {
        let signUpPage = "signuppage2"
        
        step("Given I navigate to \(signUpPage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + signUpPage, true)
        }
        
        verifyPwManagerNotDisplayedTextField(field: "First Name: ", data: firstName)
        verifyPwManagerNotDisplayedTextField(field: "Last Name: ", data: lastName)
        fillDataWithoutPwManager(field: "Email: ", data: loginEmail)
        fillPasswordFieldWithSuggestedPassword()
        verifyPwManagerNotDisplayedTextField(field: "Phone: ", data: phone)
        verifyPwManagerNotDisplayedTextField(field: "Gender: ", data: gender)
        verifyPwManagerNotDisplayedDropdown(field: "Month: ", data: month)
        verifyPwManagerNotDisplayedTextField(field: "Day: ", data: day)
        verifyPwManagerNotDisplayedTextField(field: "Year: ", data: year)
        
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the result page is populated with sign up data") {
            alertView.notNowClick() // will fail if pop up is not displayed
            XCTAssertEqual(mockPage.getResultValue(label: "email"), loginEmail)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), generatedPassword)
        }
    }
    
    func testSignUpPageCombination3() {
        let signUpPage = "signuppage3"
        
        step("Given I navigate to \(signUpPage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + signUpPage, true)
        }
        
        verifyPwManagerNotDisplayedTextField(field: "Phone: ", data: phone)
        fillDataWithoutPwManager(field: "Email: ", data: loginEmail)
        fillDataWithoutPwManager(field: "Confirm Email: ", data: loginEmail)
        verifyPwManagerNotDisplayedTextField(field: "Birthdate: ", data: year)
        fillPasswordFieldWithSuggestedPassword()
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the result page is populated with sign up data") {
            alertView.notNowClick() // will fail if pop up is not displayed
            XCTAssertEqual(mockPage.getResultValue(label: "email"), loginEmail)
            XCTAssertEqual(mockPage.getResultValue(label: "password"), generatedPassword)
        }
    }
    
    func testSignUpPageCombination4() {
        let signUpPage = "signuppage4"

        step("Given I navigate to \(signUpPage)") {
            OmniBoxTestView().searchInOmniBox(baseUrl + signUpPage, true)
        }
        
        verifyPwManagerNotDisplayedTextField(field: "First Name: ", data: firstName)
        verifyPwManagerNotDisplayedTextField(field: "Last Name: ", data: lastName)
        verifyPwManagerNotDisplayedTextField(field: "Birthdate: ", data: year)
        fillDataWithoutPwManager(field: "Email: ", data: loginEmail)
        fillPasswordFieldWithSuggestedPassword()
        XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "Confirm Password: ", inView: view)), securedAutoCompletedPassword)
        
        step("When I submit the form") {
            mockPage.getContinueButtonElement(inView: view).clickOnExistence()
        }
        
        step("Then the result page is populated with sign up data") {
            alertView.notNowClick() // will fail if pop up is not displayed
            XCTAssertEqual(mockPage.getResultValue(label: "subscriptionEmail"), loginEmail)
            XCTAssertEqual(mockPage.getResultValue(label: "subscriptionPassword"), generatedPassword)
            XCTAssertEqual(mockPage.getResultValue(label: "subscriptionPasswordConfirmation"), generatedPassword)

        }
    }
    
}
        
