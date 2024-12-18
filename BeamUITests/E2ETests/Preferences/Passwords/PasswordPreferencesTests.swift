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
    let hostnameNeverSaved = "neversaved.form.lvh.me"
    let hostnameLvh = "signin.form.lvh.me"
    let badHostname = "g"
    let usernameExample = "quentin"
    let passwordExample = "quentin"
    
    func setup(isPasswordProtectionDisabled: Bool = true, doPopulatePasswordsDB: Bool = true) {
        step ("GIVEN I open password preferences"){
            super.setUp()
            if isPasswordProtectionDisabled {
                uiMenu.invoke(.disablePasswordProtect)
            }
            if doPopulatePasswordsDB {
                uiMenu.invoke(.populatePasswordsDB)
            }
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            PreferencesBaseView().navigateTo(preferenceView: .passwords)
        }
    }
    
    func verifyPasswordPopUpDisplay(_ siteValue: String, _ usernameValue: String, _ passwordValue: String, _ update: Bool = false) {
        XCTAssertTrue(passwordPreferencesView.isFormToFillPasswordDisplayed(update))
        XCTAssertEqual(passwordPreferencesView.getPasswordFieldToFill(.site).getStringValue(), siteValue)
        XCTAssertEqual(passwordPreferencesView.getPasswordFieldToFill(.username).getStringValue(), usernameValue)
        XCTAssertEqual(passwordPreferencesView.getPasswordFieldToFill(.password).getStringValue(), passwordValue)
    }
    
    func addPassword(_ siteValue: String, _ usernameValue: String, _ passwordValue: String) {
        passwordPreferencesView.getPasswordFieldToFill(.site).clickClearAndType(siteValue, true)
        passwordPreferencesView.getPasswordFieldToFill(.username).clickClearAndType(usernameValue, true)
        passwordPreferencesView.getPasswordFieldToFill(.password).clickClearAndType(passwordValue, true)
        passwordPreferencesView.clickAddPassword()
        waitForDoesntExist(passwordPreferencesView.getPasswordFieldToFill(.site))
    }
    
    func testPasswordProtectionLock() {
        testrailId("C625")
        setup(isPasswordProtectionDisabled: false, doPopulatePasswordsDB: false)
        
        step ("THEN I see the view is locked"){
            XCTAssertTrue(passwordPreferencesView.staticText(PasswordPreferencesViewLocators.StaticTexts.passwordProtectionTitle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            // Increased timeout to match deadline of updateHasTouchID in LockedPasswordsView
            XCTAssertTrue(passwordPreferencesView.app.windows.staticTexts.matching(NSPredicate(format: "value BEGINSWITH  '\(PasswordPreferencesViewLocators.StaticTexts.passwordProtectionDescription.accessibilityIdentifier)'")).firstMatch.waitForExistence(timeout: TimeInterval(1)))
            XCTAssertTrue(passwordPreferencesView.getUnlockButtonElement().isEnabled)
            XCTAssertFalse(passwordPreferencesView.checkBox(PasswordPreferencesViewLocators.CheckboxTexts.autofillPasswords.accessibilityIdentifier).exists)
        }
    }
    
    func testAddPasswordItem() {
        testrailId("C628")
        setup(isPasswordProtectionDisabled: true, doPopulatePasswordsDB: false)
        
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
        testrailId("C629")
        setup()
        var alertView: AlertTestView!
        
        step ("WHEN I click to delete password entry \(hostnameApple)"){
            passwordPreferencesView.selectFirstPasswordItem(hostnameApple)
            if BaseTest().isBigSurOS() {
                passwordPreferencesView.clickCancel()
            }
            alertView = passwordPreferencesView.clickRemove()
        }
        
        step ("AND I do not confirm deletion"){
            XCTAssertTrue(alertView.cancelDeletionFromSheets())
        }
        
        step ("THEN password entry \(hostnameApple) is not deleted"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
        }
        
        step ("WHEN I click to delete password entry \(hostnameApple)"){
            if !BaseTest().isBigSurOS() {
                passwordPreferencesView.selectFirstPasswordItem(hostnameApple)
            }
            passwordPreferencesView.clickRemove()
        }
        
        step ("AND I confirm deletion"){
            XCTAssertTrue(alertView.confirmRemoveFromSheets())
        }
        
        step ("THEN password entry \(hostnameApple) is correctly deleted"){
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy(hostnameApple))
        }
    }
    
    func testViewPasswordItemDetails() {
        testrailId("C630")
        setup()
        
        step ("WHEN I click to see password details of \(hostnameApple)"){
            passwordPreferencesView.selectFirstPasswordItem(hostnameApple)
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
            passwordPreferencesView.selectFirstPasswordItem(hostnameApple)
            passwordPreferencesView.clickDetails()
            passwordPreferencesView.getPasswordFieldToFill(.username).clickClearAndType("user1Update", true)
            passwordPreferencesView.clickDone()
        }
        
        step ("THEN username of \(hostnameApple) is updated"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy("user1Update"))
            XCTAssertFalse(passwordPreferencesView.isPasswordDisplayedBy("quentin"))
        }
        
    }
    
    func testSearchForPassword() {
        testrailId("C626")
        setup()
        
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
    
    func testSortPasswords() {
        testrailId("C631")
        setup()
        
        step ("WHEN I click on Sites to sort passwords"){
            passwordPreferencesView.sortPasswords()
        }

        step ("THEN password entries are correctly sorted"){
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(0).getStringValue(), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(1).getStringValue(), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(2).getStringValue(), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(3).getStringValue(), hostnameNeverSaved)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(4).getStringValue(), hostnameFacebook)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(5).getStringValue(), hostnameApple)
        }
        
        
        step ("WHEN I click again on Sites to sort passwords"){
            passwordPreferencesView.sortPasswords()
        }

        step ("THEN password entries are correctly sorted"){
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(0).getStringValue(), hostnameApple)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(1).getStringValue(), hostnameFacebook)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(2).getStringValue(), hostnameNeverSaved)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(3).getStringValue(), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(4).getStringValue(), hostnameLvh)
            XCTAssertEqual(passwordPreferencesView.getPasswordByIndex(5).getStringValue(), hostnameLvh)
        }
        
    }
    
    func testAutofillUsernameAndPasswords() {
        testrailId("C627")
        setup()
        
        step ("WHEN I go to Password Manager Test page"){
            shortcutHelper.shortcutActionInvoke(action: .close)
            uiMenu.invoke(.loadUITestPagePassword)
            testPage.clickInputField(.username)
        }
        
        step ("THEN Autofill is proposed"){
            passwordManagerHelper.getKeyIconElement().hoverAndTapInTheMiddle()
            XCTAssertTrue(passwordManagerHelper.getOtherPasswordsOptionElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
        }

        step ("WHEN I deactivate Autofill password setting"){
            uiMenu.invoke(.disablePasswordProtect)
            shortcutHelper.shortcutActionInvoke(action: .openPreferences)
            if (passwordPreferencesView.getUnlockButtonElement().exists) {
            passwordPreferencesView.getUnlockButtonElement().hoverAndTapInTheMiddle()
            }
            passwordPreferencesView.clickAutofillPassword()
        }
        
        step ("THEN Autofill password settings is disabled"){
            XCTAssertFalse(passwordPreferencesView.getAutofillPasswordSettingElement().isSettingEnabled())
            shortcutHelper.shortcutActionInvoke(action: .close)
        }

        step ("AND Autofill is not proposed anymore"){
            uiMenu.invoke(.loadUITestPagePassword)
            testPage.clickInputField(.username)
            XCTAssertFalse(passwordManagerHelper.getKeyIconElement().waitForExistence(timeout: BaseTest.minimumWaitTimeout))
            XCTAssertFalse(passwordManagerHelper.getOtherPasswordsOptionElement().exists)
        }
    }
    
    func testNeverSavedPasswordItem() {
        setup()

        step ("WHEN I search for \(hostnameNeverSaved)"){
            passwordPreferencesView.searchForPasswordBy("neversaved")
        }
        step ("THEN the password is 'never saved'"){
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy(hostnameNeverSaved))
            XCTAssertTrue(passwordPreferencesView.isPasswordDisplayedBy("never saved"))
        }
        step ("WHEN I click on \(hostnameNeverSaved)"){
            passwordPreferencesView.selectFirstPasswordItem(hostnameNeverSaved)
        }
        step ("THEN details button is disabled"){
            XCTAssertFalse(passwordPreferencesView.button(PasswordPreferencesViewLocators.Buttons.detailsButton.accessibilityIdentifier).isEnabled)
        }
    }

    func testImportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
    
    func testExportPasswords() throws {
        try XCTSkipIf(true, "WIP")
    }
}
