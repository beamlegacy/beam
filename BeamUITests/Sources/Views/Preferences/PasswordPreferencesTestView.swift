//
//  PasswordPreferencesTestsView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 17/02/2022.
//

import Foundation
import XCTest

class PasswordPreferencesTestView: PreferencesBaseView {
    
    let usernameColumnTitle = "Username"
    let sitesColumnTitle = "Sites"
    let passwordsColumnTitle = "Passwords"
    
    var passwordTables : XCUIElementQuery {
            get {
             return app.windows[passwordsColumnTitle].tables
            }
        }
    
    @discardableResult
    func clickCancel() -> PasswordPreferencesTestView {
        button(PasswordPreferencesViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return PasswordPreferencesTestView()
    }
    
    @discardableResult
    func clickFill() -> PasswordPreferencesTestView {
        button(PasswordPreferencesViewLocators.Buttons.fillButton.accessibilityIdentifier).clickOnExistence()
        return PasswordPreferencesTestView()
    }
    
    @discardableResult
    func clickRemove() -> AlertTestView {
        button(PasswordPreferencesViewLocators.Buttons.removeButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func clickAddPassword() -> AlertTestView {
        button(PasswordPreferencesViewLocators.Buttons.addPasswordButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func clickDetails() -> AlertTestView {
        button(PasswordPreferencesViewLocators.Buttons.detailsButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func clickDone() -> AlertTestView {
        button(PasswordPreferencesViewLocators.Buttons.doneButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func clickAutofillPassword() -> PasswordPreferencesTestView {
        checkBox(PasswordPreferencesViewLocators.CheckboxTexts.windowTitle.accessibilityIdentifier).clickOnExistence()
        return PasswordPreferencesTestView()
    }
    
    @discardableResult
    func isAutofillPasswordEnabled() -> Bool {
        let enabled = (checkBox(PasswordPreferencesViewLocators.CheckboxTexts.windowTitle.accessibilityIdentifier).value as? Int == 1) ? true : false
        return enabled
    }
    
    @discardableResult
    func searchForPasswordBy(_ searchKeyword: String) -> PasswordPreferencesTestView {
        textField(PasswordPreferencesViewLocators.TextFields.searchField.accessibilityIdentifier).clickOnExistence()
        textField(PasswordPreferencesViewLocators.TextFields.searchField.accessibilityIdentifier).clickClearAndType(searchKeyword)
        return self
    }
    
    func isPasswordDisplayed() -> Bool {
        return passwordTables.children(matching: .tableRow).element(boundBy: 0).staticTexts[usernameColumnTitle].waitForExistence(timeout: minimumWaitTimeout)
    }
    
    @discardableResult
    func selectPassword(_ text: String) -> PasswordPreferencesTestView {
        passwordTables.children(matching: .tableRow).element(boundBy: 0).staticTexts[text].clickOnExistence()
        return self
    }
    
    @discardableResult
    func getPasswordByIndex(_ index: Int) -> XCUIElement {
        return passwordTables.children(matching: .tableRow).element(boundBy: index).staticTexts.firstMatch
    }
    
    @discardableResult
    func sortPasswords() -> PasswordPreferencesTestView {
        passwordTables.buttons[sitesColumnTitle].clickOnExistence()
        return self
    }
    
    func isPasswordDisplayedBy(_ text: String) -> Bool {
        return staticText(text).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isErrorDisplayed() -> Bool {
        return staticText(PasswordPreferencesViewLocators.StaticTexts.siteError.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isAddPasswordButtonEnabled() -> Bool {
        return button(PasswordPreferencesViewLocators.Buttons.addPasswordButton.accessibilityIdentifier).isEnabled
    }
    
    func isFormToFillPasswordDisplayed( _ update: Bool = false) -> Bool {
        let mainButton = (update) ? button(PasswordPreferencesViewLocators.Buttons.doneButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout) : button(PasswordPreferencesViewLocators.Buttons.addPasswordButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
        return (
                button(PasswordPreferencesViewLocators.Buttons.cancelButton.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
                && getPasswordFieldToFill(PasswordFieldToFill.site).waitForExistence(timeout: minimumWaitTimeout)
                && getPasswordFieldToFill(PasswordFieldToFill.username).waitForExistence(timeout: minimumWaitTimeout)
                && getPasswordFieldToFill(PasswordFieldToFill.password).waitForExistence(timeout: minimumWaitTimeout)
                && mainButton
        )
    }
    
    func waitForFormToFillPasswordToClose() -> Bool {
        return WaitHelper().waitForDoesntExist(button(PasswordPreferencesViewLocators.Buttons.cancelButton.accessibilityIdentifier))
    }
    
    func getPasswordFieldToFill(_ field: PasswordFieldToFill) -> XCUIElement {
        return app.windows[passwordsColumnTitle].sheets.children(matching: .textField).element(boundBy: field.rawValue)
    }
    
    enum PasswordFieldToFill: Int, CaseIterable {
        case site = 0
        case username = 1
        case password = 2
    }
    
}
