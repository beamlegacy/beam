//
//  SignInAutocompleteTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class SignInAutocompleteTests: BaseTest {
    
    let signInPageURL = "http://signin.form.lvh.me:8080/"
    let uiMenu = UITestsMenuBar()
    let mockPage = MockHTTPWebPages()
    let helper = PasswordManagerHelper()
    
    private func credentialsAutocompleteAssertion(login: String) {
        step("THEN after clicking on pop-up login text the credentials are successfully populated"){
            helper.clickPopupLoginText(login: login)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getEmailFieldElement()), login)
            XCTAssertEqual(mockPage.getElementStringValue(element: mockPage.getPasswordFieldElement(false)), "••••••••••")
        }
    }
    
    func testCredentialsAutocompleteSuccessfully() {
        let login = "signin.form"
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
        OmniBoxTestView().searchInOmniBox(signInPageURL, true)
        
        step("GIVEN I click on password field"){
            mockPage.getPasswordFieldElement(false).clickOnExistence()
        }

        self.credentialsAutocompleteAssertion(login: login)
        ShortcutsHelper().shortcutActionInvoke(action: .reloadPage)
        
        step("GIVEN I click on email field"){
            mockPage.getEmailFieldElement().clickOnExistence()
        }
        
        self.credentialsAutocompleteAssertion(login: login)
    }
    
    func testOtherPasswordsAppearanceRemovalFill() {
        let login = "qa@beamapp.co"
        let journalView = launchApp()
        
        step("Given I populate passwords and load a test page"){
            uiMenu.populatePasswordsDB()
            OmniBoxUITestsHelper(journalView.app).tapCommand(.loadUITestPagePassword)
        }
        let passwordPage = UITestPagePasswordManager()
        
        step("When I click Other passwords option"){
            passwordPage.clickInputField(.password)
        }
        let passPrefView = helper.openPasswordPreferences()
        
        step("Then Password preferences window is opened"){
            XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
            XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
        }

        step("Then Password preferences window is closed on cancel click"){
            passPrefView.clickCancel()
            XCTAssertTrue(passPrefView.waitForPreferenceToClose())
            XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
        }

        step("Then authentication fields are NOT auto-populated"){
            XCTAssertEqual(passwordPage.getInputValue(.username), emptyString)
            XCTAssertEqual(passwordPage.getInputValue(.password), emptyString)
        }

        step("When I open Other passwords option and cancel password remove"){
            helper.openPasswordPreferences()
            passPrefView.staticTextTables("apple.com").clickOnExistence()
        }
        
        let alertView = passPrefView.clickRemove()

        step("Then it is not removed from the list of passwords"){
            XCTAssertTrue(alertView.cancelDeletionFromDialogSheets())
            XCTAssertTrue(passPrefView.staticTextTables("apple.com").exists)
        }

        step("Then it is removed from the list of passwords"){
            passPrefView.clickRemove()
            XCTAssertTrue(alertView.confirmRemoveFromSheets())
            XCTAssertTrue(waitForDoesntExist(passPrefView.staticTextTables("apple.com")))
        }

        step("When I choose Fill option for another password"){
            passPrefView.staticTextTables("facebook.com").clickOnExistence()
            passPrefView.clickFill()
            XCTAssertTrue(passPrefView.waitForPreferenceToClose())
        }

        step("Then authentication fields are auto-populated"){
            XCTAssertEqual(passwordPage.getInputValue(.username), login)
            XCTAssertEqual(passwordPage.getInputValue(.password), "••••••••••")
        }

    }
    
    func SKIPtestSearchPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
    func SKIPtestSortPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
}
