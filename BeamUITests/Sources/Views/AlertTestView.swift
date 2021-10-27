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
        button(AlertViewLocators.Buttons.alertDeleteButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(button(AlertViewLocators.Buttons.alertDeleteButton.accessibilityIdentifier))
        return self
    }
    
    @discardableResult
    func cancelDeletion() -> BaseView {
        button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier))
        return self
    }
    
    @discardableResult
    func savePassword(waitForAlertToDisappear: Bool) -> BaseView {
        button(AlertViewLocators.Buttons.alertSavePasswordButton.accessibilityIdentifier).clickOnExistence()
        if waitForAlertToDisappear {
            WaitHelper().waitForDoesntExist(button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier))
        }
        return self
    }
    
    @discardableResult
    func notNowClick() -> BaseView {
        button(AlertViewLocators.Buttons.alertNotNowButton.accessibilityIdentifier).clickOnExistence()
        WaitHelper().waitForDoesntExist(button(AlertViewLocators.Buttons.alertCancelButton.accessibilityIdentifier))
        return self
    }
}
