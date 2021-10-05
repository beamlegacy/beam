//
//  PasswordsTestView.swift
//  BeamUITests
//
//  Created by Andrii on 28/09/2021.
//

import Foundation
import XCTest

class PasswordsTestView: BaseView {
    
    @discardableResult
    func clickCancel() -> WebTestView {
        app/*@START_MENU_TOKEN@*/.sheets/*[[".dialogs.sheets",".sheets"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.buttons[PasswordViewLocators.Buttons.cancelButton.accessibilityIdentifier].clickOnHittable()
        return WebTestView()
    }
    
    func isPasswordPreferencesOpened() -> Bool {
        return app/*@START_MENU_TOKEN@*/.dialogs.sheets/*[[".dialogs.sheets",".sheets"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.staticTexts[PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier].waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func waitForPreferenceToClose() -> Bool {
        return WaitHelper().waitForDoesntExist(staticText(PasswordViewLocators.StaticTexts.windowTitle.accessibilityIdentifier))
    }
    
}
