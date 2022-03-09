//
//  PasswordPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class PasswordPreferencesTests: BaseTest {
    
    let shortcutsHelper = ShortcutsHelper()
    let uiMenu = UITestsMenuBar()
    let passwordsWindow = PasswordPreferencesTestView()
    let testPage = UITestPagePasswordManager()
    let hostnameGoogle = "google.com"
    let hostnameApple = "apple.com"
    let hostnameFacebook = "facebook.com"
    let hostnameLvh = "signin.form.lvh.me"
    let badHostname = "g"
    let usernameExample = "quentin"
    let passwordExample = "quentin"
    
    func setup() {
        launchApp()
        uiMenu.clearPasswordsDB()
        
        testRailPrint("GIVEN I open password preferences")
        shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(menu: .passwords)
    }
    
    func verifyPasswordPopUpDisplay(_ siteValue: String, _ usernameValue: String, _ passwordValue: String, _ update: Bool = false) {
        XCTAssertTrue(passwordsWindow.isFormToFillPasswordDisplayed(update))
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.site)), siteValue)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.username)), usernameValue)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordFieldToFill(.password)), passwordValue)
    }
    
    func addPassword(_ siteValue: String, _ usernameValue: String, _ passwordValue: String) {
        passwordsWindow.getPasswordFieldToFill(.site).clickAndType(siteValue)
        passwordsWindow.getPasswordFieldToFill(.username).clickAndType(usernameValue)
        passwordsWindow.getPasswordFieldToFill(.password).clickAndType(passwordValue)
        passwordsWindow.clickAddPassword()
        WaitHelper().waitForDoesntExist(passwordsWindow.getPasswordFieldToFill(.site))
    }
    
    func testAddPasswordItem() throws {
        setup()
        
        testRailPrint("AND I click on add password button")
        passwordsWindow.clickFill()
        
        testRailPrint("THEN form to fill password is displayed")
        XCTAssertTrue(passwordsWindow.isFormToFillPasswordDisplayed())
        
        testRailPrint("WHEN I click on Cancel")
        passwordsWindow.clickCancel()
        XCTAssertTrue(passwordsWindow.waitForFormToFillPasswordToClose())
        
        testRailPrint("THEN the pop-up is closed")
        XCTAssertFalse(passwordsWindow.isFormToFillPasswordDisplayed())
        
        testRailPrint("AND no data is added")
        XCTAssertFalse(passwordsWindow.isPasswordDisplayed())
        
        testRailPrint("WHEN I add password data without data")
        passwordsWindow.clickFill()
        passwordsWindow.clickAddPassword()

        testRailPrint("THEN nothing happens")
        XCTAssertFalse(passwordsWindow.isAddPasswordButtonEnabled())
        verifyPasswordPopUpDisplay(emptyString,emptyString,emptyString)

        testRailPrint("WHEN I populate hostname '\(hostnameGoogle)' only")
        passwordsWindow.getPasswordFieldToFill(.site).clickAndType(hostnameGoogle)

        testRailPrint("AND I click on Add Password")
        passwordsWindow.clickAddPassword()
        
        testRailPrint("THEN nothing happens")
        XCTAssertFalse(passwordsWindow.isAddPasswordButtonEnabled())
        verifyPasswordPopUpDisplay(hostnameGoogle,emptyString,emptyString)
        
        testRailPrint("WHEN I populate hostname '\(hostnameGoogle)' and username '\(usernameExample)' only")
        passwordsWindow.getPasswordFieldToFill(.username).clickAndType(usernameExample)

        testRailPrint("AND I click on Add Password")
        passwordsWindow.clickAddPassword()
        
        testRailPrint("THEN nothing happens")
        XCTAssertFalse(passwordsWindow.isAddPasswordButtonEnabled())
        verifyPasswordPopUpDisplay(hostnameGoogle,usernameExample,emptyString)
        
        testRailPrint("WHEN I populate wrong hostname '\(badHostname)' with all information")
        passwordsWindow.getPasswordFieldToFill(.site).clickClearAndType(badHostname)
        passwordsWindow.getPasswordFieldToFill(.password).clickAndType(usernameExample)

        testRailPrint("AND I click on Add Password")
        XCTAssertTrue(passwordsWindow.isAddPasswordButtonEnabled())
        passwordsWindow.clickAddPassword()
        
        testRailPrint("THEN error message is displayed")
        XCTAssertFalse(passwordsWindow.isAddPasswordButtonEnabled())
        XCTAssertTrue(passwordsWindow.isErrorDisplayed())
        verifyPasswordPopUpDisplay(badHostname,usernameExample,passwordExample)
        
        testRailPrint("THEN password item is successfully added when correct hostname format is typed")
        passwordsWindow.getPasswordFieldToFill(.site).clickClearAndType(hostnameGoogle)
        XCTAssertFalse(passwordsWindow.isErrorDisplayed())
        verifyPasswordPopUpDisplay(hostnameGoogle,usernameExample,passwordExample)
        passwordsWindow.clickAddPassword()
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(hostnameGoogle))
    }
    
    func testRemovePasswordItem() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        testRailPrint("WHEN I click to delete passwordentry \(hostnameApple)")
        passwordsWindow.selectPassword(hostnameApple)
        let alertView = passwordsWindow.clickRemove()
        
        testRailPrint("AND I do not confirm deletion")
        XCTAssertTrue(alertView.cancelDeletionFromSheets())
        
        testRailPrint("THEN password entry \(hostnameApple) is not deleted")
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(hostnameApple))
        
        testRailPrint("WHEN I click to delete password entry \(hostnameApple)")
        passwordsWindow.selectPassword(hostnameApple)
        passwordsWindow.clickRemove()
        
        testRailPrint("AND I confirm deletion")
        XCTAssertTrue(alertView.confirmRemoveFromSheets())
        
        testRailPrint("THEN password entry \(hostnameApple) is correctly deleted")
        XCTAssertFalse(passwordsWindow.isPasswordDisplayedBy(hostnameApple))
    }
    
    func testViewPasswordItemDetails() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        testRailPrint("WHEN I click to see password details of \(hostnameApple)")
        passwordsWindow.selectPassword(hostnameApple)
        passwordsWindow.clickDetails()
        
        testRailPrint("THEN password details of \(hostnameApple) are displayed")
        verifyPasswordPopUpDisplay(hostnameApple,"user1","password1", true)
        XCTAssertFalse(passwordsWindow.getPasswordFieldToFill(.site).isEnabled)
        
        testRailPrint("WHEN I click on cancel")
        passwordsWindow.clickCancel()
        
        testRailPrint("THEN details are closed")
        XCTAssertFalse(passwordsWindow.isFormToFillPasswordDisplayed())
        
        testRailPrint("WHEN I update username of \(hostnameApple)")
        passwordsWindow.selectPassword(hostnameApple)
        passwordsWindow.clickDetails()
        passwordsWindow.getPasswordFieldToFill(.username).clickClearAndType("user1Update")
        passwordsWindow.clickDone()
        
        testRailPrint("THEN username of \(hostnameApple) is updated")
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy("user1Update"))
        XCTAssertFalse(passwordsWindow.isPasswordDisplayedBy("quentin"))
        
    }
    
    func testSearchForPassword() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        testRailPrint("WHEN I search for specific password entry 'apple'")
        passwordsWindow.searchForPasswordBy("apple")
        
        testRailPrint("THEN \(hostnameApple) is correctly displayed")
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(hostnameApple))
        XCTAssertFalse(passwordsWindow.isPasswordDisplayedBy(hostnameFacebook))
        XCTAssertFalse(passwordsWindow.isPasswordDisplayedBy(hostnameLvh))
        
        testRailPrint("WHEN I search for a non existing password entry 'google10'")
        passwordsWindow.searchForPasswordBy("google10")
        
        testRailPrint("THEN empty result is returned")
        XCTAssertFalse(passwordsWindow.isPasswordDisplayed())
        
        testRailPrint("WHEN I search for multiple passwords with '.com' keyword")
        passwordsWindow.searchForPasswordBy(".com")
        
        testRailPrint("THEN they are all listed")
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(hostnameApple))
        XCTAssertTrue(passwordsWindow.isPasswordDisplayedBy(hostnameFacebook))
        XCTAssertFalse(passwordsWindow.isPasswordDisplayedBy(hostnameLvh))
    }
    
    func testSortPasswords() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        testRailPrint("WHEN I click on Sites to sort passwords")
        passwordsWindow.sortPasswords()

        testRailPrint("THEN password entries are correctly sorted")
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(0)), hostnameLvh)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(1)), hostnameFacebook)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(2)), hostnameApple)
        
        testRailPrint("WHEN I click again on Sites to sort passwords")
        passwordsWindow.sortPasswords()

        testRailPrint("THEN password entries are correctly sorted")
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(0)), hostnameApple)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(1)), hostnameFacebook)
        XCTAssertEqual(passwordsWindow.getElementStringValue(element: passwordsWindow.getPasswordByIndex(2)), hostnameLvh)
    }
    
    func testAutofillUsernameAndPasswords() throws {
        let helper = BeamUITestsHelper(launchApp().app)
        uiMenu.clearPasswordsDB()
        
        testRailPrint("GIVEN I open password preferences")
        shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(menu: .passwords)
        uiMenu.populatePasswordsDB()
        
        testRailPrint("THEN Autofill password settings is enabled")
        if (!passwordsWindow.isAutofillPasswordEnabled()) {
            passwordsWindow.clickAutofillPassword()
        }
        XCTAssertTrue(passwordsWindow.isAutofillPasswordEnabled())
        
        testRailPrint("WHEN I go to Password Manager Test page")
        XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        testPage.clickInputField(.username)
        
        testRailPrint("THEN Autofill is proposed")
        XCTAssertTrue(PasswordManagerHelper().getOtherPasswordsOptionElement().exists)
        
//        Not doing following steps with real website because of https://linear.app/beamapp/issue/BE-3291/pwmanager-not-proposed-directly-to-user-on-google
//        testRailPrint("WHEN I go to Facebook Login page")
//        testPage.openWebsite("facebook.com")
//        XCUIApplication().windows/*@START_MENU_TOKEN@*/.webViews["Facebook – log in or sign up"].textFields["Email address or phone number"]/*[[".groups",".scrollViews.webViews[\"Facebook – log in or sign up\"]",".groups.textFields[\"Email address or phone number\"]",".textFields[\"Email address or phone number\"]",".webViews[\"Facebook – log in or sign up\"]"],[[[-1,4,2],[-1,1,2],[-1,0,1]],[[-1,4,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.clickOnExistence()
//
//        testRailPrint("THEN Autofill is proposed")
//        XCTAssertTrue(PasswordManagerHelper().getOtherPasswordsOptionElement().exists)
//        XCTAssertTrue(PasswordManagerHelper().doesAutofillPopupExist(login: "qa@beamapp.co"))

        testRailPrint("WHEN I deactivate Autofill password setting")
        shortcutsHelper.shortcutActionInvoke(action: .openPreferences)
        PreferencesBaseView().navigateTo(menu: .passwords)
        passwordsWindow.clickAutofillPassword()
        
        testRailPrint("THEN Autofill password settings is disabled")
        XCTAssertFalse(passwordsWindow.isAutofillPasswordEnabled())
        XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        
        testRailPrint("AND Autofill is not proposed anymore")
        helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
        testPage.clickInputField(.username)
        XCTAssertFalse(PasswordManagerHelper().getOtherPasswordsOptionElement().exists)
        
    }
    
    func testImportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testExportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
}
