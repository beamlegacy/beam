//
//  AccountTestView.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest
import BeamCore

class AccountTestView: PreferencesBaseView {
    
    func getLoginFieldElement() -> XCUIElement {
        _ = textField(AccountViewLocators.TextFields.login.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return textField(AccountViewLocators.TextFields.login.accessibilityIdentifier)
    }
    
    func getLoginFieldValue() -> String {
        return getElementStringValue(element: getLoginFieldElement())
    }
    
    func getPasswordFieldElement() -> XCUIElement {
        _ = secureTextField(AccountViewLocators.TextFields.password.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return secureTextField(AccountViewLocators.TextFields.password.accessibilityIdentifier)
    }
    
    func getPasswordFieldValue() -> String {
        return getElementStringValue(element: getPasswordFieldElement())
    }
    
    func signIn() -> Bool {
        let loginField = getLoginFieldElement()
        let passwordField = getPasswordFieldElement()
        let email = "andrii+test@beamapp.co"//EnvironmentVariables.Account.testEmail
        let password = "B8:T{E=J=3tL9FL?"//EnvironmentVariables.Account.testPassword
        
        loginField.tapInTheMiddle()
        
        if getLoginFieldValue() != "" {
            selectAllAndDelete()
        }
        loginField.typeText(email)
        self.typeKeyboardKey(.escape)
        passwordField.tapInTheMiddle()
        
        if getPasswordFieldValue() != "" {
            selectAllAndDelete()
        }
        pasteText(textToPaste: password)
        self.typeKeyboardKey(.escape)
        button(AccountViewLocators.Buttons.signinButton.accessibilityIdentifier).clickOnEnabled()
        return false
    }
    
    func getConnectToBeamButtonElement() -> XCUIElement {
        return button(AccountViewLocators.Buttons.connectBeamButton.accessibilityIdentifier)
    }
}
