//
//  PasswordSuggestionPopupTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 03.02.2022.
//

import Foundation
import XCTest

class PasswordSuggestionPopupTestView: BaseView {
    
    func doesTitleExist() -> Bool {
        return app.staticTexts["Suggested Password"].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func doesDescriptionExist() -> Bool {
        return app.staticTexts["Beam created a strong password for this website.\nLook up your saved passwords in Beam Passwords preferences."].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func getDontUseButton() -> XCUIElement {
        return app.buttons[PasswordSuggestionPopupViewLocators.Buttons.dontUseButton.accessibilityIdentifier]
    }
    
    func getUsePasswordButton() -> XCUIElement {
        return app.buttons[PasswordSuggestionPopupViewLocators.Buttons.usePasswordButton.accessibilityIdentifier]
    }

}
