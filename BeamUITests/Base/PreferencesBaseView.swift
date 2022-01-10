//
//  PreferencesBaseView.swift
//  BeamUITests
//
//  Created by Andrii on 07/10/2021.
//

import Foundation
import XCTest

class PreferencesBaseView: BaseView {
    
    func labelSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.staticTexts[element]
    }
    
    func textFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.textFields[element]
    }
    
    func textViewSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.textViews[element]
    }
    
    func staticTextSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.staticTexts[element]
    }
    
    func searchFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.searchFields[element]
    }
    
    func secureTextFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.secureTextFields[element]
    }
    
    func checkBoxSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.checkBoxes[element]
    }
    
    func buttonSheets(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.buttons[element]
    }
    
    func labelTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.staticTexts[element]
    }
    
    func textFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.textFields[element]
    }
    
    func textViewTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.textViews[element]
    }
    
    func staticTextTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.staticTexts[element]
    }
    
    func searchFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.searchFields[element]
    }
    
    func secureTextFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.secureTextFields[element]
    }
    
    func checkBoxTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.checkBoxes[element]
    }
    
    func buttonTables(_ element: String) -> XCUIElement {
        return app.dialogs.sheets.tables.buttons[element]
    }
    
    enum PreferenceMenus {
        case general
        case browser
        case notes
        case privacy
        case passwords
        case account
        case about
        case advanced
    }
    
    @discardableResult
    func navigateTo(menu: PreferenceMenus) -> PreferencesBaseView {
        switch menu {
        case .general:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.generalButton.accessibilityIdentifier].click()
        case .browser:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.browserButton.accessibilityIdentifier].click()
        case .notes:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.notesButton.accessibilityIdentifier].click()
        case .privacy:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.privacyButton.accessibilityIdentifier].click()
        case .passwords:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.passwordsButton.accessibilityIdentifier].click()
        case .account:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.accountButton.accessibilityIdentifier].click()
        case .about:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.aboutButton.accessibilityIdentifier].click()
        case .advanced:
            app.toolbars.buttons[PreferencesToolbarViewLocators.Buttons.advancedButton.accessibilityIdentifier].click()
        }
        return self
    }
}
