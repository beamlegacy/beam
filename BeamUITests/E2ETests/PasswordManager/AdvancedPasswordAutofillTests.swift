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

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
    }

    func testHiddenFieldsAreIgnored() {
        let url = "http://form.lvh.me:8080/visibility"
        let login = "signin.form"
        let password = "somePass@0"

        OmniBoxTestView().searchInOmniBox(url, true)

        step("When I click on password field") {
            mockPage.getPasswordFieldElement(title: "Current Password: ").clickOnExistence()
        }
        step("When I click on pop-up suggestion") {
            helper.clickPopupLoginText(login: login)
        }
        step("Then the credentials are successfully populated") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "Current Username: ")), login)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "Current Password: ")), "••••••••••")
        }

        step("When I click on sign up link") {
            mockPage.getLinkElement("Sign Up").clickOnExistence()
        }
        step("Then the credentials are empty") {
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getUsernameFieldElement(title: "New Username: ")), "")
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(title: "New Password: ")), "")
        }

        step("When I submit the form") {
            mockPage.button("Continue").clickOnExistence()
        }
        step("Then the results page is populated with sign in data") {
            XCTAssertEqual(mockPage.getResultValue(label: "username1"), login)
            XCTAssertEqual(mockPage.getResultValue(label: "password1"), password)
            XCTAssertNil(mockPage.getResultValue(label: "username2"))
            XCTAssertNil(mockPage.getResultValue(label: "password2"))
        }
    }

}
