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
    
    func testAutocompleteSuccessfullyAppears() {
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
        
        testRailPrint("Then the field is successfully autofilled on autofill pop-up click")
        helper.getAutofillPopupElement().click()
        
        if !WaitHelper().waitForStringValueEqual(helper.login, emailField) || helper.doesAutofillPopupExist() {
            helper.getAutofillPopupElement().click()
        }

        XCTAssertTrue(WaitHelper().waitForStringValueEqual(helper.login, emailField), "email field is \(String(describing: emailField.value)) and autofill pop-up existence is \(helper.doesAutofillPopupExist())")
        XCTAssertEqual(passwordField.value as? String, "••••••••••")
        XCTAssertFalse(helper.doesAutofillPopupExist())                        
    }
    
    func testOtherPasswordsAppearance() {
        let journalView = launchApp()
        UITestsMenuBar().populatePasswordsDB()
        let helper = PasswordManagerHelper()
        BeamUITestsHelper(journalView.app).tapCommand(.resizeSquare1000)
        testRailPrint("When I click Other passwords option")
        let webView = journalView.searchInOmniBar(facebookPage, true)
        XCTAssertTrue(self.handleWebsiteIsNotOpened(webView), "Google page is still opened")
        XCTAssertTrue(self.handleFacebookCookiesPopup(webView), "facebook cookies pop-up blocks the web page")
        let passPrefView = helper.openPasswordPreferences()
        
        testRailPrint("Then Password preferences window is opened")
        XCTAssertTrue(passPrefView.isPasswordPreferencesOpened())
        XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
        
        testRailPrint("Then Password preferences window is closed on cancel click")
        passPrefView.clickCancel()
        XCTAssertTrue(passPrefView.waitForPreferenceToClose())
        XCTAssertTrue(helper.getOtherPasswordsOptionElement().exists)
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
    
    override func tearDown() {
        UITestsMenuBar().destroyDB()
    }
}
