//
//  AutoFillCCTestView.swift
//  BeamUITests
//
//  Created by Quentin Valero on 23/05/2022.
//

import Foundation
import XCTest

class AutoFillCCTestView: PreferencesBaseView {
    
    @discardableResult
    func clickCancel() -> WebTestView {
        buttonSheets(AutofillCCViewLocators.Buttons.cancelButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickFill() -> WebTestView {
        buttonSheets(AutofillCCViewLocators.Buttons.fillButton.accessibilityIdentifier).clickOnExistence()
        return WebTestView()
    }
    
    @discardableResult
    func clickRemove() -> AlertTestView {
        buttonSheets(AutofillCCViewLocators.Buttons.removeButton.accessibilityIdentifier).clickOnExistence()
        return AlertTestView()
    }
    
    func isCCPreferencesOpened() -> Bool {
        return staticTextSheets(AutofillCCViewLocators.StaticTexts.windowTitle.accessibilityIdentifier).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func isCCDisplayedBy(_ text: String) -> Bool {
        return staticTextTables(text).waitForExistence(timeout: BaseTest.minimumWaitTimeout)
    }
    
    func waitForPreferenceToClose() -> Bool {
        return waitForDoesntExist(staticText(AutofillCCViewLocators.StaticTexts.windowTitle.accessibilityIdentifier))
    }
}
