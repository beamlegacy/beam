//
//  OnboardingPrivateKeyTestView.swift
//  BeamUITests
//
//  Created by Andrii on 12/04/2022.
//

import Foundation
import XCTest

class OnboardingPrivateKeyTestView: BaseView {
    
    func getContinueButton() -> XCUIElement {
        return button(OnboardingPrivateKeyViewLocators.Buttons.importButton.accessibilityIdentifier)
    }
    
    func getBackButton() -> XCUIElement {
        return staticText(OnboardingPrivateKeyViewLocators.Buttons.backButton.accessibilityIdentifier)
    }
    
    func getImportPKFileButton() -> XCUIElement {
        return button(OnboardingPrivateKeyViewLocators.Buttons.importPKButton.accessibilityIdentifier)
    }
    
    func getCantFindPKButton() -> XCUIElement {
        return staticText(OnboardingPrivateKeyViewLocators.Buttons.cantFindPKButton.accessibilityIdentifier)
    }
    
    func getPKTextField() -> XCUIElement {
        return textField(OnboardingPrivateKeyViewLocators.TextFields.privateKeyTextField.accessibilityIdentifier)
    }
    
    func waitForPKViewLoaded() -> Bool {
        return staticText(OnboardingPrivateKeyViewLocators.StaticTexts.pkViewTitle.accessibilityIdentifier).waitForExistence(timeout: minimumWaitTimeout)
    }
    
    func clickContinueButton() -> OnboardingImportDataTestView {
        getContinueButton().tapInTheMiddle()
        return OnboardingImportDataTestView()
    }
    
    func getErrorTitle() -> XCUIElement {
        return app.staticTexts["This private key file doesn’t match this user account"]
    }
    
    func getErrorDescription() -> XCUIElement {
        return app.staticTexts["You need to import the private key file matching this user account."]
    }
    
    func cantFindPKButtonClick() -> OnboardingLostPKTestView {
        getCantFindPKButton().tapInTheMiddle()
        return OnboardingLostPKTestView()
    }
    
    func setPKAndClickContinueButton(privateKey: String) -> OnboardingImportDataTestView {
        getPKTextField().clickAndType(privateKey)
        getContinueButton().tapInTheMiddle()
        return OnboardingImportDataTestView()
    }
    
}
