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
    
    func testPasswordMenuIsHiddenWhenOmniboxIsVisible() {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
        OmniBoxTestView().searchInOmniBox(signInPageURL, true)

        step("When I click on password field"){
            mockPage.getPasswordFieldElement(false).clickOnExistence()
        }
        step("Then the key icon is visible"){
            XCTAssertTrue(helper.getKeyIconElement().exists)
        }

        step("When I show the omnibox"){
            ShortcutsHelper().shortcutActionInvoke(action: .showOmnibox)
        }
        step("Then the key icon is hidden"){
            XCTAssertFalse(helper.getKeyIconElement().exists)
        }

        step("When I dismiss the omnibox"){
            helper.typeKeyboardKey(.escape)
        }
        step("Then the key icon is visible again"){
            XCTAssertTrue(helper.getKeyIconElement().exists)
        }
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

        step("Then Password preferences window is opened, and menu isn't visible anymore"){
            XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
            XCTAssertFalse(helper.getOtherPasswordsOptionElement().exists)
        }

        step("Then Password preferences window is closed on cancel click"){
            passPrefView.clickCancel()
            XCTAssertTrue(passPrefView.waitForPreferenceToClose())
            XCTAssertFalse(helper.getOtherPasswordsOptionElement().exists)
        }

        step("Then authentication fields are NOT auto-populated"){
            XCTAssertEqual(passwordPage.getInputValue(.username), emptyString)
            XCTAssertEqual(passwordPage.getInputValue(.password), emptyString)
        }

        step("When I click key icon") {
            helper.clickKeyIcon()
        }

        step("Then passwords menu is visible again") {
            XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
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

    func testOtherPasswordsSearch() {
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

        step("Then Password preferences window is opened, and menu isn't visible anymore"){
            XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
            XCTAssertFalse(helper.getOtherPasswordsOptionElement().exists)
        }

        step("Then the list shows entries for apple.com and facebook.com"){
            XCTAssertTrue(passPrefView.staticTextTables("apple.com").exists)
            XCTAssertTrue(passPrefView.staticTextTables("facebook.com").exists)
        }

        step("When I search for apple"){
            passPrefView.searchForPasswordBy("apple")
        }

        step("Then the list shows apple.com and not facebook.com"){
            XCTAssertTrue(passPrefView.staticTextTables("apple.com").exists)
            XCTAssertFalse(passPrefView.staticTextTables("facebook.com").exists)
        }

        step("When I empty the search field"){
            helper.typeKeyboardKey(.delete)
            helper.typeKeyboardKey(.delete)
            helper.typeKeyboardKey(.delete)
            helper.typeKeyboardKey(.delete)
            helper.typeKeyboardKey(.delete)
        }

        step("Then the list shows apple.com and facebook.com again"){
            XCTAssertTrue(passPrefView.staticTextTables("apple.com").exists)
            XCTAssertTrue(passPrefView.staticTextTables("facebook.com").exists)
        }
    }

    func SKIPtestSearchPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
    func SKIPtestSortPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
}
