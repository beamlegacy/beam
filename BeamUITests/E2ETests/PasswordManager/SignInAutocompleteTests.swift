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
    let signUpPageURL = "http://signup.form.lvh.me:8080/"
    
    private func credentialsAutocompleteAssertion(login: String) {
        step("THEN after clicking on pop-up login text the credentials are successfully populated"){
            passwordManagerHelper.clickPopupLoginText(login: login)
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "Username: ").getStringValue(), login)
            XCTAssertEqual(mockPage.getPasswordFieldElement(false).getStringValue(), "••••••••••")
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
        shortcutHelper.shortcutActionInvoke(action: .reloadPage)
        
        step("GIVEN I click on email field"){
            mockPage.getUsernameFieldElement(title: "Username: ").clickOnExistence()
        }
        
        self.credentialsAutocompleteAssertion(login: login)
    }
    
    func testPasswordMenuIsHiddenWhenOmniboxIsVisible() {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
        mockPage.openMockPage(.signinForm)

        step("When I click on password field"){
            mockPage.getPasswordFieldElement(false).clickOnExistence()
        }
        
        step("Then the key icon is visible"){
            XCTAssertTrue(passwordManagerHelper.getKeyIconElement().exists)
        }

        step("When I show the omnibox"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
        }
        
        step("Then the key icon is hidden"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }

        step("When I dismiss the omnibox"){
            passwordManagerHelper.typeKeyboardKey(.escape)
        }
        
        step("Then the key icon is visible again"){
            XCTAssertTrue(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    func testPasswordMenuIsHiddenWhenOmniboxTriggersTabChange() {
        launchApp()
        uiMenu.destroyDB()
            .startMockHTTPServer()
            .populatePasswordsDB()
        mockPage.openMockPage(.signinForm)

        step("When I click on password field"){
            mockPage.getPasswordFieldElement(false).clickOnExistence()
        }
        
        step("Then the key icon is visible"){
            XCTAssertTrue(passwordManagerHelper.getKeyIconElement().exists)
        }

        step("When I show the omnibox"){
            shortcutHelper.shortcutActionInvoke(action: .showOmnibox)
        }
        step("Then the key icon is hidden"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }

        step("When I open a new tab"){
            OmniBoxTestView().searchInOmniBox(signUpPageURL, true)
        }
        step("Then the key icon is still hidden"){
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().exists)
        }
    }

    func testOtherPasswordsAppearanceRemovalFill() {
        let login = "qa@beamapp.co"
        launchApp()
        
        step("Given I populate passwords and load a test page"){
            uiMenu.populatePasswordsDB()
            uiMenu.loadUITestPagePassword()
        }
        let passwordPage = UITestPagePasswordManager()
        
        step("When I click password field") {
            passwordPage.clickInputField(.password)
        }
        step("Then the menu is not displayed") {
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step("When I click key icon") {
            passwordManagerHelper.clickKeyIcon()
        }

        var passPrefView: AutoFillPasswordsTestView!
        step("And I click Other passwords option") {
            passPrefView = passwordManagerHelper.openPasswordPreferences()
        }

        step("Then Password preferences window is opened, and menu isn't visible anymore"){
            XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step("Then Password preferences window is closed on cancel click"){
            passPrefView.clickCancel()
            XCTAssertTrue(passPrefView.waitForPreferenceToClose())
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step("Then authentication fields are NOT auto-populated"){
            XCTAssertEqual(passwordPage.getInputValue(.username), emptyString)
            XCTAssertEqual(passwordPage.getInputValue(.password), emptyString)
        }

        step("When I click key icon") {
            passwordManagerHelper.clickKeyIcon()
        }

        step("Then passwords menu is visible again") {
            XCTAssertTrue(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step("When I open Other passwords option and cancel password remove"){
            passwordManagerHelper.openPasswordPreferences()
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
        launchApp()

        step("Given I populate passwords and load a test page"){
            uiMenu.populatePasswordsDB()
            uiMenu.loadUITestPagePassword()
        }
        let passwordPage = UITestPagePasswordManager()

        step("When I click password field") {
            passwordPage.clickInputField(.password)
        }
        step("Then the menu is not displayed") {
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step("When I click key icon") {
            passwordManagerHelper.clickKeyIcon()
        }

        var passPrefView: AutoFillPasswordsTestView!
        step("And I click Other passwords option") {
            passPrefView = passwordManagerHelper.openPasswordPreferences()
        }

        step("Then Password preferences window is opened, and menu isn't visible anymore"){
            XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
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
            passwordManagerHelper.typeKeyboardKey(.delete)
            passwordManagerHelper.typeKeyboardKey(.delete)
            passwordManagerHelper.typeKeyboardKey(.delete)
            passwordManagerHelper.typeKeyboardKey(.delete)
            passwordManagerHelper.typeKeyboardKey(.delete)
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
