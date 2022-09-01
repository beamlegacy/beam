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
    
    func isForgetTabGroupAlertDisplayed(tabGroupName: String) -> Bool {
        _ = app.staticTexts[ AlertViewLocators.StaticTexts.forgetTabGroupTitle.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        let bodyString = AlertViewLocators.StaticTexts.forgetTabGroupBody.accessibilityIdentifier
        let newString = bodyString.replacingOccurrences(of: "%tabGroupName%", with: tabGroupName, options: .literal, range: nil)

        return app.staticTexts[newString].exists && app.staticTexts[ AlertViewLocators.StaticTexts.forgetTabGroupTitle.accessibilityIdentifier].exists
    }
    
    func isDeleteTabGroupAlertDisplayed(tabGroupName: String, captured:Bool = true, noteTitle: String? = nil) -> Bool {
        _ = app.staticTexts[ AlertViewLocators.StaticTexts.deleteTabGroupTitle.accessibilityIdentifier].waitForExistence(timeout: BaseTest.minimumWaitTimeout)
        var newString = ""
        if captured {
            let bodyString = AlertViewLocators.StaticTexts.deleteCapturedTabGroupBody.accessibilityIdentifier
            newString = bodyString.replacingOccurrences(of: "%tabGroupName%", with: tabGroupName, options: .literal, range: nil)
                .replacingOccurrences(of: "%noteTitle%", with: noteTitle!, options: .literal, range: nil)
        } else {
            let bodyString = AlertViewLocators.StaticTexts.deleteNotCapturedTabGroupBody.accessibilityIdentifier
            newString = bodyString.replacingOccurrences(of: "%tabGroupName%", with: tabGroupName, options: .literal, range: nil)
        }

        return app.staticTexts[newString].exists && app.staticTexts[ AlertViewLocators.StaticTexts.deleteTabGroupTitle.accessibilityIdentifier].exists
    }
}
