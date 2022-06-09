//
//  PasswordPreferencesTests.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class PasswordPreferencesTests: BaseTest {
    
    let passwordPreferencesView = PasswordPreferencesTestView()
    let testPage = UITestPagePasswordManager()
    let hostnameGoogle = "google.com"
    let hostnameApple = "apple.com"
    let hostnameFacebook = "facebook.com"
    let hostnameLvh = "signin.form.lvh.me"
    let badHostname = "g"
    let usernameExample = "quentin"
    let passwordExample = "quentin"
    
    func setup() {
        step ("GIVEN I open password preferences"){
            launchApp()
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
        }
    }
    
    func verifyPasswordPopUpDisplay(_ siteValue: String, _ usernameValue: String, _ passwordValue: String, _ update: Bool = false) {
        XCTAssertTrue(passwordPreferencesView.isFormToFillPasswordDisplayed(update))
        XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordFieldToFill(.site)), siteValue)
        XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordFieldToFill(.username)), usernameValue)
        XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordFieldToFill(.password)), passwordValue)
    }
    
    func addPassword(_ siteValue: String, _ usernameValue: String, _ passwordValue: String) {
        passwordPreferencesView.getPasswordFieldToFill(.site).clickClearAndType(siteValue, true)
        passwordPreferencesView.getPasswordFieldToFill(.username).clickClearAndType(usernameValue, true)
        passwordPreferencesView.getPasswordFieldToFill(.password).clickClearAndType(passwordValue, true)
        passwordPreferencesView.clickAddPassword()
        waitForDoesntExist(passwordPreferencesView.getPasswordFieldToFill(.site))
    }
    
    func testAddPasswordItem() throws {
        setup()
        
        step ("AND I click on add password button"){
            passwordPreferencesView.clickFill()
        }
        
        step ("THEN form to fill password is displayed"){
            XCTAssertTrue(passwordPreferencesView.isFormToFillPasswordDisplayed())
        }
        
        step ("WHEN I click on Cancel"){
            passwordPreferencesView.clickCancel()
            XCTAssertTrue(passwordPreferencesView.waitForFormToFillPasswordToClose())
        }
        
        step ("THEN the pop-up is closed"){
            XCTAssertFalse(passwordPreferencesView.isFormToFillPasswordDisplayed())
        }

        step ("AND no data is added"){
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayed())
        }
        
        step ("WHEN I add password data without data"){
            passwordPreferencesView.clickFill()
            passwordPreferencesView.clickAddPassword()
        }
        
        step ("THEN nothing happens"){
            XCTAssertFalse(passwordPreferencesView.isAddPasswordButtonEnabled())
            verifyPasswordPopUpDisplay(emptyString,emptyString,emptyString)
        }

        step ("WHEN I populate hostname '\(hostnameGoogle)' only"){
            passwordPreferencesView.getPasswordFieldToFill(.site).clickClearAndType(hostnameGoogle, true)
        }

        step ("AND I click on Add Password"){
            passwordPreferencesView.clickAddPassword()
        }
        
        step ("THEN nothing happens"){
            XCTAssertFalse(passwordPreferencesView.isAddPasswordButtonEnabled())
            verifyPasswordPopUpDisplay(hostnameGoogle,emptyString,emptyString)
        }
        
        step ("WHEN I populate hostname '\(hostnameGoogle)' and username '\(usernameExample)' only"){
            passwordPreferencesView.getPasswordFieldToFill(.username).clickClearAndType(usernameExample, true)
        }

        step ("AND I click on Add Password"){
            passwordPreferencesView.clickAddPassword()
        }
        
        step ("THEN nothing happens"){
            XCTAssertFalse(passwordPreferencesView.isAddPasswordButtonEnabled())
            verifyPasswordPopUpDisplay(hostnameGoogle,usernameExample,emptyString)
        }
        
        step ("WHEN I populate wrong hostname '\(badHostname)' with all information"){
            passwordPreferencesView.getPasswordFieldToFill(.site).clickClearAndType(badHostname, true)
            passwordPreferencesView.getPasswordFieldToFill(.password).clickClearAndType(usernameExample, true)
        }
        
        step ("AND I click on Add Password"){
            XCTAssertTrue(passwordPreferencesView.isAddPasswordButtonEnabled())
            passwordPreferencesView.clickAddPassword()
        }
        
        step ("THEN error message is displayed"){
            XCTAssertFalse(passwordPreferencesView.isAddPasswordButtonEnabled())
            XCTAssertTrue(passwordPreferencesView.isErrorDisplayed())
            verifyPasswordPopUpDisplay(badHostname,usernameExample,passwordExample)
        }
        
        step ("THEN password item is successfully added when correct hostname format is typed"){
            passwordPreferencesView.getPasswordFieldToFill(.site).clickClearAndType(hostnameGoogle, true)
            XCTAssertFalse(passwordPreferencesView.isErrorDisplayed())
            verifyPasswordPopUpDisplay(hostnameGoogle,usernameExample,passwordExample)
            passwordPreferencesView.clickAddPassword()
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameGoogle))
        }
        
    }
    
    func testRemovePasswordItem() throws {
        setup()
        var alertView: AlertTestView?
        step ("WHEN I click to delete passwordentry \(hostnameApple)"){
            uiMenu.populatePasswordsDB()
            passwordPreferencesView.selectPassword(hostnameApple)
            alertView = passwordPreferencesView.clickRemove()
        }
        
        step ("AND I do not confirm deletion"){
            XCTAssertTrue(alertView!.cancelDeletionFromSheets())
        }
        
        step ("THEN password entry \(hostnameApple) is not deleted"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
        }
        
        step ("WHEN I click to delete password entry \(hostnameApple)"){
            passwordPreferencesView.selectPassword(hostnameApple)
            passwordPreferencesView.clickRemove()
        }
        
        step ("AND I confirm deletion"){
            XCTAssertTrue(alertView!.confirmRemoveFromSheets())
        }
        
        step ("THEN password entry \(hostnameApple) is correctly deleted"){
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
        }
    }
    
    func testViewPasswordItemDetails() throws {
        setup()
        
        step ("WHEN I click to see password details of \(hostnameApple)"){
            uiMenu.populatePasswordsDB()
            passwordPreferencesView.selectPassword(hostnameApple)
            passwordPreferencesView.clickDetails()
        }
        
        
        step ("THEN password details of \(hostnameApple) are displayed"){
            verifyPasswordPopUpDisplay(hostnameApple,"user1","password1", true)
            XCTAssertFalse(passwordPreferencesView.getPasswordFieldToFill(.site).isEnabled)
        }
        
        step ("WHEN I click on cancel"){
            passwordPreferencesView.clickCancel()
        }
        
        step ("THEN details are closed"){
            XCTAssertFalse(passwordPreferencesView.isFormToFillPasswordDisplayed())
        }
        
        step ("WHEN I update username of \(hostnameApple)"){
            passwordPreferencesView.selectPassword(hostnameApple)
            passwordPreferencesView.clickDetails()
            passwordPreferencesView.getPasswordFieldToFill(.username).clickClearAndType("user1Update", true)
            passwordPreferencesView.clickDone()
        }
        
        step ("THEN username of \(hostnameApple) is updated"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy("user1Update"))
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy("quentin"))
        }
        
    }
    
    func testSearchForPassword() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        step ("WHEN I search for specific password entry 'apple'"){
            passwordPreferencesView.searchForPasswordBy("apple")
        }
        
        step ("THEN \(hostnameApple) is correctly displayed"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy(hostnameFacebook))
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy(hostnameLvh))
        }
        
        step ("WHEN I search for a non existing password entry 'google10'"){
            passwordPreferencesView.searchForPasswordBy("google10")
        }
        
        step ("THEN empty result is returned"){
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayed())
        }
        
        step ("WHEN I search for multiple passwords with '.com' keyword"){
            passwordPreferencesView.searchForPasswordBy(".com")
        }
        
        step ("THEN they are all listed"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameFacebook))
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy(hostnameLvh))
        }
        
    }
    
    func testSortPasswords() throws {
        setup()
        uiMenu.populatePasswordsDB()
        
        step ("WHEN I click on Sites to sort passwords"){
            passwordPreferencesView.sortPasswords()
        }

        step ("THEN password entries are correctly sorted"){
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(0)), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(1)), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(2)), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(3)), hostnameFacebook)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(4)), hostnameApple)
        }
        
        
        step ("WHEN I click again on Sites to sort passwords"){
            passwordPreferencesView.sortPasswords()
        }

        step ("THEN password entries are correctly sorted"){
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(0)), hostnameApple)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(1)), hostnameFacebook)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(2)), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(3)), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getElementStringValue(element: passwordPreferencesView.getPasswordByIndex(4)), hostnameLvh)
        }
        
    }
    
    func testAutofillUsernameAndPasswords() throws {
        // Test deactivated on Test Plan because we don't have an easy way to restore preferences settings after this test
        // Especially in case of failure at the middle of the test
        let helper = BeamUITestsHelper(launchApp().app)
        
        step ("GIVEN I open password preferences"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            uiMenu.populatePasswordsDB()
        }
        
        step ("THEN Autofill password settings is enabled"){
            if (!passwordPreferencesView.isSettingEnabled(element: passwordPreferencesView.getAutofillPasswordSettingElement())) {
                passwordPreferencesView.clickAutofillPassword()
            }
            XCTAssertTrue(passwordPreferencesView.isSettingEnabled(element: passwordPreferencesView.getAutofillPasswordSettingElement()))
        }
        
        
        step ("WHEN I go to Password Manager Test page"){
            XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
            testPage.clickInputField(.username)
        }
        
        step ("THEN Autofill is proposed"){
            XCTAssertTrue(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }

        step ("WHEN I deactivate Autofill password setting"){
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
            passwordPreferencesView.clickAutofillPassword()
        }
        
        step ("THEN Autofill password settings is disabled"){
            XCTAssertFalse(passwordPreferencesView.isSettingEnabled(element: passwordPreferencesView.getAutofillPasswordSettingElement()))
            XCUIApplication().windows["Passwords"].buttons[XCUIIdentifierCloseWindow].clickOnExistence()
        }

        step ("AND Autofill is not proposed anymore"){
            helper.openTestPage(page: BeamUITestsHelper.UITestsPageCommand.password)
            testPage.clickInputField(.username)
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }
    }
    
    func testImportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testExportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
}
