//
//  SignInAutocompleteTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest
import BeamCore

class SignInAutocompleteTests: BaseTest {
    
    let signInPageURL = "http://signin.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
    let signUpPageURL = "http://signup.form.lvh.me:\(EnvironmentVariables.MockHttpServer.port)/"
    
    private func credentialsAutocompleteAssertion(login: String) {
        step("THEN after clicking on pop-up login text the credentials are successfully populated"){
            passwordManagerHelper.clickPopupLoginText(login: login)
            XCTAssertEqual(mockPage.getUsernameFieldElement(title: "Username: ").getStringValue(), login)
            XCTAssertEqual(mockPage.getPasswordFieldElement(false).getStringValue(), "••••••••••")
        }
    }
    
    func testCredentialsAutocompleteSuccessfully() {
        let login = "signin.form"
        uiMenu.invoke(.startMockHttpServer)
            .invoke(.populatePasswordsDB)
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
        testrailId("C1080")
        uiMenu.invoke(.startMockHttpServer)
            .invoke(.populatePasswordsDB)
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
        testrailId("C1081")
        uiMenu.invoke(.startMockHttpServer)
            .invoke(.populatePasswordsDB)
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

    func testOtherPasswordsAppearanceRemovalFill() throws {
        testrailId("C1082")
        try XCTSkipIf(isBigSurOS(), "Reactivate once BE-5032 is fixed")

        let login = "qa@beamapp.co"
        
        step("Given I populate passwords and load a test page"){
            uiMenu.invoke(.populatePasswordsDB)
                .invoke(.disablePasswordProtect)
                .invoke(.loadUITestPagePassword)
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
        testrailId("C1083")

        step("Given I populate passwords and load a test page"){
            uiMenu.invoke(.populatePasswordsDB)
                .invoke(.disablePasswordProtect)
                .invoke(.loadUITestPagePassword)
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

    func testSaveAlertDoesNotAppearIfHostHasDoNotSave() {
        uiMenu.invoke(.startMockHttpServer)
            .invoke(.populatePasswordsDB)
        mockPage.openMockPage(.neverSavedShortForm)

        step("When I click on username field"){
            mockPage.getUsernameFieldElement(title: "Username: ").tapInTheMiddle()
        }
        step("And I type credentials"){
            mockPage.app.typeText("username999")
            mockPage.typeKeyboardKey(.tab)
            mockPage.app.typeText("password999")
        }

        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        step("Then the save alert is not displayed"){
            XCTAssertFalse(mockPage.button(AlertViewLocators.Buttons.savePasswordButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        step("And the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), "username999")
            XCTAssertEqual(mockPage.getResultValue(label: "password"), "password999")
        }
    }

    func testDoNotSaveOptionIsAvailable() {
        uiMenu.invoke(.startMockHttpServer)
            .invoke(.populatePasswordsDB)
        mockPage.openMockPage(.notSavedShortForm)

        step("When I click on username field"){
            mockPage.getUsernameFieldElement(title: "Username: ").tapInTheMiddle()
        }
        step("And I type credentials"){
            mockPage.app.typeText("username999")
            mockPage.typeKeyboardKey(.tab)
            mockPage.app.typeText("password999")
        }

        step("When I submit the form") {
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        step("Then the save alert is displayed"){
            XCTAssertTrue(mockPage.button(AlertViewLocators.Buttons.savePasswordButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        step("And the 'Never for this website' button is available"){
            XCTAssertTrue(mockPage.button(AlertViewLocators.Buttons.neverSavePasswordButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step("When I click on 'Never save'"){
            mockPage.button(AlertViewLocators.Buttons.neverSavePasswordButton.accessibilityIdentifier).clickInTheMiddle()
        }
        step("Then the save alert is dismissed"){
            XCTAssertFalse(mockPage.button(AlertViewLocators.Buttons.savePasswordButton.accessibilityIdentifier).exists)
        }
        step("And the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), "username999")
            XCTAssertEqual(mockPage.getResultValue(label: "password"), "password999")
        }

        step("When I sign in as another user"){
            mockPage.getLinkElement("Back", inView: "Mock Form Server").tapInTheMiddle()
            mockPage.getUsernameFieldElement(title: "Username: ").tapInTheMiddle()
            mockPage.app.typeText("username000")
            mockPage.typeKeyboardKey(.tab)
            mockPage.app.typeText("password000")
            mockPage.getContinueButtonElement().clickOnExistence()
        }
        step("Then the save alert is not displayed"){
            XCTAssertFalse(mockPage.button(AlertViewLocators.Buttons.savePasswordButton.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }
        step("And the results page is populated with sign in data") {
            mockPage.waitForContinueButtonToDisappear()
            XCTAssertEqual(mockPage.getResultValue(label: "username"), "username000")
            XCTAssertEqual(mockPage.getResultValue(label: "password"), "password000")
        }
    }
}
