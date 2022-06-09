//
//  OneFieldAutofillTests.swift
//  BeamUITests
//
//  Created by Frank Lefebvre on 20/04/2022.
//

import Foundation
import XCTest

class OneFieldAutofillTests: BaseTest {

    let baseURL = "http://form.lvh.me:8080/custom"

    override func setUpWithError() throws {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
    }

    func testTextFieldAloneDoesNotTriggerAutofill() {
        OmniBoxTestView().searchInOmniBox("\(baseURL)?label1=Field&id1=field1", true)

        step("When I click on text field") {
            mockPage.getUsernameFieldElement(title: "Field: ").clickOnExistence()
        }
        step("Then the key icon is not displayed"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    // When personal info is implemented this will trigger autofill with email
    func testTextFieldWithEmailAutocompleteDoesNotTriggerAutofill() {
        OmniBoxTestView().searchInOmniBox("\(baseURL)?label1=Field&autocomplete1=email&id1=field1", true)

        step("When I click on text field") {
            mockPage.getUsernameFieldElement(title: "Field: ").clickOnExistence()
        }
        step("Then the key icon is not displayed"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    // When personal info is implemented this will trigger autofill with email
    func testEmailFieldAloneDoesNotTriggerAutofill() {
        OmniBoxTestView().searchInOmniBox("\(baseURL)?label1=Field&type1=email&id1=field1", true)

        step("When I click on text field") {
            mockPage.getUsernameFieldElement(title: "Field: ").clickOnExistence()
        }
        step("Then the key icon is not displayed"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    func testTextFieldWithUsernameAutocompleteTriggersAutofill() {
        OmniBoxTestView().searchInOmniBox("\(baseURL)?label1=Field&autocomplete1=username&id1=field1", true)

        step("When I click on text field") {
            mockPage.getUsernameFieldElement(title: "Field: ").clickOnExistence()
        }
        step("Then the key icon is displayed"){
            XCTAssertTrue(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    func testEmailFieldWithUsernameAutocompleteTriggersAutofill() {
        OmniBoxTestView().searchInOmniBox("\(baseURL)?label1=Field&type1=email&autocomplete1=username&id1=field1", true)

        step("When I click on text field") {
            mockPage.getUsernameFieldElement(title: "Field: ").clickOnExistence()
        }
        step("Then the key icon is displayed"){
            XCTAssertTrue(passwordManagerHelper.getKeyIconElement().exists)
        }
    }
}
