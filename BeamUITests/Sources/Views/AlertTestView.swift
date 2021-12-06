//
//  AlertTestView.swift
//  BeamUITests
//
//  Created by Andrii on 06/10/2021.
//

import Foundation
import XCTest

class AlertTestView: BaseView {
    
    @discardableResult
    func confirmDeletion() -> BaseView {
        let deleteButton = button(AlertViewLocators.Buttons.alertDeleteButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(deleteButton)
        return self
    }
    
    @discardableResult
    func cancelDeletion() -> BaseView {
        let cancelButton = button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(cancelButton)
        return self
    }
    
    @discardableResult
    func confirmRemoveFromSheets() -> BaseView {
        let deleteButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.alertRemoveButton.accessibilityIdentifier].clickOnExistence()
        WaitHelper().waitForDoesntExist(deleteButton)
        return self
    }
    
    @discardableResult
    func cancelDeletionFromSheets() -> BaseView {
        let cancelButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier].clickOnExistence()
        WaitHelper().waitForDoesntExist(cancelButton)
        return self
    }
    
    @discardableResult
    func savePassword(waitForAlertToDisappear: Bool) -> BaseView {
        let savePassButton = button(AlertViewLocators.Buttons.alertSavePasswordButton.accessibilityIdentifier).clickOnExistence()
        if waitForAlertToDisappear {
            WaitHelper().waitForDoesntExist(savePassButton)
        }
        return self
    }
    
    @discardableResult
    func notNowClick() -> BaseView {
        let notNowButton = button(AlertViewLocators.Buttons.alertNotNowButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(notNowButton)
        return self
    }
    
    @discardableResult
    func exitNowClick() -> BaseView {
        self.getAlertDialog().buttons["Exit now"].click()
        return self
    }
    
    private func getAlertDialogFromSheets() -> XCUIElement {
        return app.dialogs.sheets["alert"]
    }
    
    func getAlertDialog() -> XCUIElement {
        return app.dialogs["alert"]
    }
}
