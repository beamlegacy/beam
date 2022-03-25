//
//  AlertTestView.swift
//  BeamUITests
//
//  Created by Andrii on 06/10/2021.
//

import Foundation
import XCTest

class AlertTestView: BaseView {
    
    let alert = "alert"
    let exitButtonText = "Exit now"
    let restartButtonText = "Restart Beam now"
    
    @discardableResult
    func confirmDeletion() -> BaseView {
        let deleteButton = button(AlertViewLocators.Buttons.alertDeleteButton.accessibilityIdentifier).clickOnHittable()
        waitForDoesntExist(deleteButton)
        return self
    }
    
    @discardableResult
    func cancelDeletion() -> BaseView {
        let cancelButton = button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier).clickOnHittable()
        waitForDoesntExist(cancelButton)
        return self
    }
    
    @discardableResult
    func confirmRemoveFromDialogSheets() -> Bool {
        let deleteButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.alertRemoveButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(deleteButton)
    }
    
    @discardableResult
    func cancelDeletionFromDialogSheets() -> Bool {
        let cancelButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(cancelButton)
    }

    @discardableResult
    func confirmRemoveFromSheets() -> Bool {
        let deleteButton = getAlertFromSheets().buttons[AlertViewLocators.Buttons.alertRemoveButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(deleteButton)
    }
    
    @discardableResult
    func cancelDeletionFromSheets() -> Bool {
        let cancelButton = getAlertFromSheets().buttons[AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(cancelButton)
    }
    
    @discardableResult
    func savePassword(waitForAlertToDisappear: Bool) -> BaseView {
        let savePassButton = button(AlertViewLocators.Buttons.alertSavePasswordButton.accessibilityIdentifier).clickOnExistence()
        if waitForAlertToDisappear {
            waitForDoesntExist(savePassButton)
        }
        return self
    }
    
    @discardableResult
    func notNowClick() -> BaseView {
        let notNowButton = button(AlertViewLocators.Buttons.alertNotNowButton.accessibilityIdentifier).clickOnExistence()
        waitForDoesntExist(notNowButton)
        return self
    }
    
    @discardableResult
    func exitNowClick() -> BaseView {
        self.getAlertDialog().buttons[exitButtonText].click()
        return self
    }

    @discardableResult
    func restartNowClick() -> BaseView {
        self.getAlertDialog().buttons[restartButtonText].click()
        return self
    }
    
    private func getAlertFromSheets() -> XCUIElement {
        return app.sheets[alert]
    }
    
    private func getAlertDialogFromSheets() -> XCUIElement {
        return app.dialogs.sheets[alert]
    }

    func getAlertDialog() -> XCUIElement {
        return app.dialogs[alert]
    }
}
