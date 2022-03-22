//
//  PasswordsTestView.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation
import XCTest

class AutoFillPasswordsTestView: PreferencesBaseView {
    
    @discardableResult
    func clickCancel() -> WebTestView {
        buttonSheets(AutofillPasswordViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickFill() -> WebTestView {
        buttonSheets(AutofillPasswordViewLocators.Buttons.fillButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickRemove() -> AlertTestView {
        buttonSheets(AutofillPasswordViewLocators.Buttons.removeButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    @discardableResult
    func searchForPasswordBy(_ searchKeyword: String) -> AutoFillPasswordsTestView {
        buttonTables(AutofillPasswordViewLocators.TextFields.searchField.accessibilityIdentifier).clickOnExistence()
        buttonTables(AutofillPasswordViewLocators.TextFields.searchField.accessibilityIdentifier).typeText(searchKeyword)
        return self
    }
    
    func isPasswordPreferencesOpened() -> Bool {
        return staticTextSheets(AutofillPasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isPasswordDisplayedBy(_ text: String) -> Bool {
        return staticTextTables(text).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func waitForPreferenceToClose() -> Bool {
        return waitForDoesntExist(staticText(AutofillPasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier))
    }
    
}
