//
//  BaseView.swift
//  BeamUITests
//
//  Created by Andrii on 23.07.2021.
//

import Foundation
import XCTest

//Designed to be inherited by Views classes following Page Object pattern
class BaseView {
    
    var app: XCUIApplication { XCUIApplication() }
    let implicitWaitTimeout = TimeInterval(10)
    let defaultPressDurationSeconds = 1.5
    
    //Wrapper over the elements
    func label(_ element: String) -> XCUIElement {
        return app.windows.staticTexts[element]
    }
    
    func textField(_ element: String) -> XCUIElement {
        return app.windows.textFields[element]
    }
    
    func textView(_ element: String) -> XCUIElement {
        return app.windows.textViews[element]
    }
    
    func staticText(_ element: String) -> XCUIElement {
        return app.windows.staticTexts[element]
    }
    
    func searchField(_ element: String) -> XCUIElement {
        return app.windows.searchFields[element]
    }
    
    func button(_ element: String) -> XCUIElement {
        return app.windows.buttons[element]
    }
    
    func image(_ element: String) -> XCUIElement {
        return app.windows.images[element]
    }
    
    func table(_ element: String) -> XCUIElement {
        return app.windows.tables[element]
    }
    
    func collection(_ element: String) -> XCUIElement {
        return app.windows.collectionViews[element]
    }
    
    func otherElement(_ element: String) -> XCUIElement {
        return app.windows.otherElements[element]
    }
    
    func scrollView(_ element: String) -> XCUIElement {
        return app.windows.scrollViews[element]
    }
    
    func tableTextField(_ element: String) -> XCUIElement {
        return app.windows.tables.textFields[element]
    }
    
    func tableImage(_ element: String) -> XCUIElement {
        return app.windows.tables.images[element]
    }
    
    func typeKeyboardKey(_ key: XCUIKeyboardKey, _ numberOfTimes: Int = 1) {
        for _ in 1...numberOfTimes {
            self.app.typeKey(key, modifierFlags: [])
        }
    }
    
    //Omni bar search field is accessible from any view
    
    func clickOmniBarSearchField() {
        otherElement(OmniBarLocators.SearchFields.omniSearchField.accessibilityIdentifier).click()
    }
    
    @discardableResult
    func searchInOmniBar(_ searchText: String, _ typeReturnButton: Bool) -> WebTestView {
        let omniSearchField = searchField(OmniBarLocators.SearchFields.omniSearchField.accessibilityIdentifier)
        omniSearchField.tapInTheMiddle()
        omniSearchField.clear()
        omniSearchField.typeText(searchText)
        if typeReturnButton {
            typeKeyboardKey(.enter)
        }
        return WebTestView()
    }
    
    func copyText(_ textToCopy: String) {
        self.staticText(textToCopy).doubleClick()
        
    }
}
