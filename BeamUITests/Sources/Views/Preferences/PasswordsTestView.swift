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
        buttonSheets(PasswordViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnHittable()
        return WebTestView()
    }
    
    func isPasswordPreferencesOpened() -> Bool {
        return staticTextSheets(PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func waitForPreferenceToClose() -> Bool {
        return WaitHelper().waitForDoesntExist(staticText(PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier))
    }
    
}
