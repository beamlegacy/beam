//
//  DialogTestView.swift
//  BeamUITests
//
//  Created by Andrii Vasyliev on 18.04.2022.
//

import Foundation
import XCTest

class DialogTestView: BaseView{
    
    func getButton(locator: AlertViewLocators.Buttons) -> XCUIElement {
        return app.dialogs.buttons[locator.accessibilityIdentifier]
    }
    
    func getStaticText(locator: AlertViewLocators.StaticTexts) -> XCUIElement {
        return app.dialogs.buttons[locator.accessibilityIdentifier]
    }
    
    func isConnectTabGroupDisplayed() -> Bool {
        _ = app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        return app.staticTexts[ AlertViewLocators.StaticTexts.connectDescriptionTabGroups.accessibilityIdentifier].exists && app.staticTexts[ AlertViewLocators.StaticTexts.connectBeam.accessibilityIdentifier].exists
    }
}
