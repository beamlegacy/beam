//
//  PasswordsTestView.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation
import XCTest

class PasswordsTestView: PreferencesBaseView {
    
    @discardableResult
    func clickCancel() -> WebTestView {
        buttonSheets(PasswordViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickFill() -> WebTestView {
        buttonSheets(PasswordViewLocators.Buttons.fillButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickRemove() -> AlertTestView {
        buttonSheets(PasswordViewLocators.Buttons.removeButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func searchForPasswordBy(_ searchKeyword: String) -> PasswordsTestView {
        buttonTables(PasswordViewLocators.TextFields.searchField.accessibilityIdentifier).clickOnExistence()
        buttonTables(PasswordViewLocators.TextFields.searchField.accessibilityIdentifier).typeText(searchKeyword)
        return self
    }
    
    func isPasswordPreferencesOpened() -> Bool {
        return staticTextSheets(PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func isPasswordDisplayedBy(_ text: String) -> Bool {
        return staticTextTables(text).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func waitForPreferenceToClose() -> Bool {
        return WaitHelper().waitForDoesntExist(staticText(PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier))
    }
    
}
