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
        let deleteButton = button(AlertViewLocators.Buttons.deleteButton.accessibilityIdentifier).clickOnHittable()
        waitForDoesntExist(deleteButton)
        return self
    }
    
    @discardableResult
    func cancelButtonClick() -> BaseView {
        let cancelButton = button(AlertViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnHittable()
        waitForDoesntExist(cancelButton)
        return self
    }
    
    @discardableResult
    func signOutButtonClick() -> BaseView {
        let cancelButton = button(AlertViewLocators.Buttons.signOutButton.accessibilityIdentifier).clickOnHittable()
        waitForDoesntExist(cancelButton)
        return self
    }
    
    func getDeleteAllCheckbox() -> XCUIElement {
        return checkBox("Delete all data on this device")
    }
    
    @discardableResult
    func confirmRemoveFromDialogSheets() -> Bool {
        let deleteButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.removeButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(deleteButton)
    }
    
    @discardableResult
    func cancelDeletionFromDialogSheets() -> Bool {
        let cancelButton = getAlertDialogFromSheets().buttons[AlertViewLocators.Buttons.cancelButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(cancelButton)
    }

    @discardableResult
    func confirmRemoveFromSheets() -> Bool {
        let deleteButton = getAlertFromSheets().buttons[AlertViewLocators.Buttons.removeButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(deleteButton)
    }
    
    @discardableResult
    func cancelDeletionFromSheets() -> Bool {
        let cancelButton = getAlertFromSheets().buttons[AlertViewLocators.Buttons.cancelButton.accessibilityIdentifier].clickOnExistence()
        return waitForDoesntExist(cancelButton)
    }
    
    @discardableResult
    func savePassword(waitForAlertToDisappear: Bool) -> BaseView {
        let savePassButton = button(AlertViewLocators.Buttons.savePasswordButton.accessibilityIdentifier).clickOnExistence()
        if waitForAlertToDisappear {
            waitForDoesntExist(savePassButton)
        }
        return self
    }
    
    @discardableResult
    func saveCreditCard(waitForAlertToDisappear: Bool) -> BaseView {
        let saveCCButton = button(AlertViewLocators.Buttons.saveCCButton.accessibilityIdentifier).clickOnExistence()
        if waitForAlertToDisappear {
            waitForDoesntExist(saveCCButton)
        }
        return self
    }
    
    @discardableResult
    func notNowClick() -> BaseView {
        let notNowButton = button(AlertViewLocators.Buttons.notNowButton.accessibilityIdentifier).clickOnExistence()
        waitForDoesntExist(notNowButton)
        return self
    }
    
    @discardableResult
    func exitNowClick() -> BaseView {
        self.getAlertDialog().buttons[exitButtonText].clickOnExistence()
        return self
    }

    @discardableResult
    func restartNowClick() -> BaseView {
        self.getAlertDialog().buttons[restartButtonText].clickOnExistence()
        return self
    }
    
    @discardableResult
    func okClick() -> BaseView {
        self.getAlertDialog().buttons[AlertViewLocators.Buttons.okButton.accessibilityIdentifier].clickOnExistence()
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
    
    func isAlertDialogDisplayed() -> Bool {
        return getAlertDialog().waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
}
