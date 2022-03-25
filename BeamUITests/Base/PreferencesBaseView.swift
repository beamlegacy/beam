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
        return app.dialogs.staticTexts[element]
    }

    func textFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.textFields[element]
    }

    func textViewSheets(_ element: String) -> XCUIElement {
        return app.dialogs.textViews[element]
    }

    func staticTextSheets(_ element: String) -> XCUIElement {
        return app.dialogs.staticTexts[element]
    }

    func searchFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.searchFields[element]
    }

    func secureTextFieldSheets(_ element: String) -> XCUIElement {
        return app.dialogs.secureTextFields[element]
    }

    func checkBoxSheets(_ element: String) -> XCUIElement {
        return app.dialogs.checkBoxes[element]
    }

    func buttonSheets(_ element: String) -> XCUIElement {
        return app.dialogs.buttons[element]
    }

    func labelTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.staticTexts[element]
    }
    
    func textFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.textFields[element]
    }
    
    func textViewTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.textViews[element]
    }
    
    func staticTextTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.staticTexts[element]
    }
    
    func searchFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.searchFields[element]
    }
    
    func secureTextFieldTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.secureTextFields[element]
    }
    
    func checkBoxTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.checkBoxes[element]
    }
    
    func buttonTables(_ element: String) -> XCUIElement {
        return app.dialogs.tables.buttons[element]
    }
    
    enum PreferenceMenus: String {
        case general = "General"
        case browser = "Browser"
        case notes = "Notes"
        case privacy = "Privacy"
        case passwords = "Passwords"
        case account = "Account"
        case about = "About"
        case beta = "Beta"
        case advanced = "Advanced"
    }
        
    func navigateTo(preferenceView: PreferenceMenus) {
        self.app.toolbars.buttons.matching(identifier: preferenceView.rawValue).firstMatch.clickOnHittable()
    }
}
