//
//  LoginPasswordAutocompleteTests.swift
//  BeamUITests
//
//  Created by Andrii on 27/09/2021.
//

import Foundation
import XCTest

class LoginPasswordAutocompleteTests: BaseTest {
    
    let facebookPage = "https://www.facebook.com "
    
    func testAutocompleteSuccessfullyAppears() throws {
        try XCTSkipIf(true, "To be refactored once https://linear.app/beamapp/issue/BE-1563/create-uitest-menu-option-having-httpsmockloginimoofcom-integration is Done")
        let journalView = launchApp()
        UITestsMenuBar().destroyDB()
        UITestsMenuBar().populatePasswordsDB()
        let helper = PasswordManagerHelper()
        BeamUITestsHelper(journalView.app).tapCommand(.resizeSquare1000)
        testRailPrint("When I open Facebook login page ")
        let webView = journalView.searchInOmniBar(facebookPage, true)
        XCTAssertTrue(handleWebsiteIsNotOpened(webView), "Google page is still opened")
        XCTAssertTrue(handleFacebookCookiesPopup(webView), "facebook cookies pop-up blocks the web page")
        let emailField = webView.textField("Email or Phone Number")
        let passwordField = webView.secureTextField("Password")
        testRailPrint("Then by default Autofill pop-up appears")
        //XCTAssertTrue(helper.doesAutofillPopupExist()) it disappears when closing popup, TODO separate scenario to be created fo it (using different website)
        
        if !emailField.exists {
            testRailPrint("Given I set English for the web site UI")
            webView.staticText("English (US)").tapInTheMiddle()
        }

        if !helper.doesAutofillPopupExist() {
            testRailPrint("Then Autofill pop-up appears when clicking on email and password fields")
            passwordField.hover()
            passwordField.tapInTheMiddle() //first password, otherwise autofill pop-up sometimes blocks password field
            XCTAssertTrue(helper.doesAutofillPopupExist())
        }
        emailField.tapInTheMiddle()
        emailField.click()
        XCTAssertTrue(helper.doesAutofillPopupExist())
        XCTAssertEqual(emailField.value as? String, "")
        
        //Field autofill is still flaky on CI, to be reviewed with possible UI redesign of Autofill pop-up
        /*testRailPrint("Then the field is successfully autofilled on autofill pop-up click")
        helper.getAutofillPopupElement().tapInTheMiddle()
        
        if !WaitHelper().waitForStringValueEqual(helper.login, emailField) || helper.doesAutofillPopupExist() {
            helper.getAutofillPopupElement().tapInTheMiddle()
        }

        XCTAssertTrue(WaitHelper().waitForStringValueEqual(helper.login, emailField), "email field is \(String(describing: emailField.value)) and autofill pop-up existence is \(helper.doesAutofillPopupExist())")
        XCTAssertEqual(passwordField.value as? String, "••••••••••")
        XCTAssertFalse(helper.doesAutofillPopupExist())*/
    }
    
    func testOtherPasswordsAppearanceRemovalFill() {
        let journalView = launchApp()
        
        testRailPrint("Given I populate passwords and load a test page")
        UITestsMenuBar().populatePasswordsDB()
        OmniBarUITestsHelper(journalView.app).tapCommand(.loadUITestPagePassword)
        let helper = PasswordManagerHelper()
        let passwordPage = UITestPagePasswordManager()
        
        testRailPrint("When I click Other passwords option")
        passwordPage.clickInputField(.password)
        let passPrefView = helper.openPasswordPreferences()
        
        testRailPrint("Then Password preferences window is opened")
        XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
        XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
        
        testRailPrint("Then Password preferences window is closed on cancel click")
        passPrefView.clickCancel()
        XCTAssertTrue(passPrefView.waitForPreferenceToClose())
        XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
        
        testRailPrint("Then authentication fields are NOT auto-populated")
        XCTAssertEqual(passwordPage.getInputValue(.username), emptyString)
        XCTAssertEqual(passwordPage.getInputValue(.password), emptyString)
        
        testRailPrint("When I open Other passwords option and cancel password remove")
        helper.openPasswordPreferences()
        passPrefView.staticTextTables("apple.com").clickOnExistence()
        let alertView = passPrefView.clickRemove()
        
        testRailPrint("Then it is not removed from the list of passwords")
        alertView.cancelDeletionFromSheets()
        XCTAssertTrue(passPrefView.staticTextTables("apple.com").exists)
        
        testRailPrint("Then it is removed from the list of passwords")
        passPrefView.clickRemove()
        alertView.confirmRemoveFromSheets()
        XCTAssertTrue(WaitHelper().waitForDoesntExist(passPrefView.staticTextTables("apple.com")))
        
        testRailPrint("When I choose Fill option for another password")
        passPrefView.staticTextTables("facebook.com").clickOnExistence()
        passPrefView.clickFill()
        XCTAssertTrue(passPrefView.waitForPreferenceToClose())
        
        testRailPrint("Then authentication fields are auto-populated")
        XCTAssertEqual(passwordPage.getInputValue(.username), "qa@beamapp.co")
        XCTAssertEqual(passwordPage.getInputValue(.password), "••••••••••")
    }
    
    func testSearchPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
    func testSortPasswords() throws {
        try XCTSkipIf(true, "Identifiers needed")
    }
    
    @discardableResult
    func handleFacebookCookiesPopup(_ webView: WebTestView) -> Bool {
        let facebookCookiesPopupAcceptButton = webView.button("Tout accepter") //French version
        if facebookCookiesPopupAcceptButton.waitForExistence(timeout: minimumWaitTimeout) {
            facebookCookiesPopupAcceptButton.clickOnHittable()
        }
        return WaitHelper().waitForDoesntExist(facebookCookiesPopupAcceptButton)
    }
    
    func handleWebsiteIsNotOpened(_ webView: WebTestView) -> Bool {
        let facebookWebsiteLinkTitle = webView.app.staticTexts["Facebook - Log In or Sign Up"].firstMatch
        if facebookWebsiteLinkTitle.waitForExistence(timeout: implicitWaitTimeout) {
            facebookWebsiteLinkTitle.tapInTheMiddle()
        }
        return WaitHelper().waitForDoesntExist(webView.image("Google"))
    }
}
